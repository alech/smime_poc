#!/usr/bin/env ruby

require 'rubygems'
require 'mail'
require 'openssl'

FROM = 'null@klink.name (S/MIME HTTP Testing)'
SUBJ = 'S/MIME HTTP Test Reply'

def rand_hex_string(size)
	OpenSSL::Random.random_bytes(size / 2).each_byte.to_a.map { |b| "%02X" % b }.join('')
end

def rand_uuid
	rand_hex_string(8) + '-' + rand_hex_string(4) + '-' + rand_hex_string(4) + '-' + rand_hex_string(4) + '-' + rand_hex_string(12)
end

def generate_cert(uuid)
	key = OpenSSL::PKey::RSA.new 512
	cert = OpenSSL::X509::Certificate.new
	cert.version = 2
	cert.serial  = 0x1337
	cert.subject = OpenSSL::X509::Name.parse "/DC=klink/DC=name/CN=PoC #{uuid}"
	cert.issuer  = OpenSSL::X509::Name.parse "/DC=klink/DC=name/CN=PoC CA"
	cert.public_key = key.public_key
	cert.not_before = Time.now - 24*60*60
	cert.not_after = cert.not_before + 1*365*24*60*60
	ef = OpenSSL::X509::ExtensionFactory.new
	cert.add_extension(ef.create_extension("authorityInfoAccess", "caIssuers;URI:http://www.klink.name/security/aia.cgi?action=report&uuid=#{uuid}"))
	# fails
	#cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
	#cert.add_extension(ef.create_extension("authorityKeyIdentifier", "keyid,issuer:always"))
	cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE"))
	cert.add_extension(ef.create_extension("keyUsage", "digitalSignature,keyEncipherment"))
	cert.add_extension(ef.create_extension("extendedKeyUsage", "emailProtection"))
	cert.sign(key, OpenSSL::Digest::SHA1.new)
	puts cert
	[key, cert]
end

def generate_smime(key, cert, text)
	flags  = 0
	flags |= OpenSSL::PKCS7::DETACHED
	pkcs7  = OpenSSL::PKCS7::sign(cert, key, text, [], flags)
	smime  = OpenSSL::PKCS7::write_smime(pkcs7, text, flags)
	smime
end

m = Mail.new(STDIN.read)

reply_address = m.reply_to ? m.reply_to : m.from

uuid = rand_uuid
key, cert = generate_cert(uuid)

text =<<"XEOF"
Content-Type: text/plain; charset=us-ascii

This message has been signed with a certificate which contains
a special authorityInfoAccess caIssuers URI. Please visit
http://www.klink.name/security/aia.cgi?action=view&uuid=#{uuid}
to see if viewing it has triggered an HTTP request.
XEOF

smime = generate_smime(key, cert, text)

response = Mail.new("From: #{FROM}\nSubject: #{SUBJ}\nTo: #{reply_address}\n#{smime}")
response.delivery_method :sendmail
response.deliver!
