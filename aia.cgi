#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use DBI;
use Data::Dumper;
use HTML::Entities;
use File::Slurp qw( slurp );

my $WORD_UUID = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';

my $cgi = CGI->new();
my $action = $cgi->param('action');
my $uuid   = $cgi->param('uuid');

if ($action ne 'report' && $action ne 'view') {
    print "Content-Type: text/plain\n\ngo away!\n";
    exit;
}
if ($uuid !~ m{\A [0-9A-F]{8}
                -
		[0-9A-F]{4}
		-
		[0-9A-F]{4}
		-
		[0-9A-F]{4}
		-
		[0-9A-F]{12} \z
	      }xms) {
    print "Content-Type: text/plain\n\ngo away.\n";
    exit;
}

my $dbh
  = DBI->connect('dbi:SQLite:dbname=/export/home/alech/smime_data/smime_db', '', '')
       or die "Could not connect to DB: $!";

if ($action eq 'report') {
    my $ip = $ENV{'REMOTE_ADDR'};
    my $ua = $ENV{'HTTP_USER_AGENT'};
   
    my $time = `date -u +"%Y-%m-%d %H:%M:%S"`;
    my $sth = $dbh->prepare('INSERT INTO hits (ip, uuid, useragent, date) VALUES (?, ?, ?, ?)') or die "Prepare failed: $!";
    $sth->execute($ip, $uuid, $ua, $time) or die "Execute failed: $! $>";
}
elsif ($action eq 'view') {
    my @results;
    if ($uuid eq $WORD_UUID) {
        @results = @{ $dbh->selectall_arrayref('SELECT * FROM hits WHERE uuid=? ORDER BY date DESC LIMIT 10', {}, $uuid) };
    }
    else {
        @results = @{ $dbh->selectall_arrayref('SELECT * FROM hits WHERE uuid=? ORDER BY date DESC', {}, $uuid) };
    }
    print "Content-Type: text/html\n\n";
    print slurp('/export/home/alech/smime_data/header.html');
    if (scalar @results == 0) {
        print slurp('/export/home/alech/smime_data/no_results.html');
    }
    else {
        if ($uuid eq $WORD_UUID) {
	    print slurp('/export/home/alech/smime_data/results_word.html');
	}
	else {
	    print slurp('/export/home/alech/smime_data/results.html');
	}
            #print Dumper(\@results);
        foreach my $result (@results) {
            #print Dumper $result;
            my $date = $result->[3];
            my $ua   = encode_entities($result->[2]);
            my $ip   = $result->[0];
            print "<li>At $date UTC from $ip using $ua";
        }
	if ($uuid eq $WORD_UUID) {
	    print slurp('/export/home/alech/smime_data/results_word_footer.html');
	}
	else {
	    print slurp('/export/home/alech/smime_data/results_footer.html');
        }
    }
    print slurp('/export/home/alech/smime_data/footer.html');
}
