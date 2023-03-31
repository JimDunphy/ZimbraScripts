#!/usr/bin/perl

#
# Author: ChatGBT4 3/30/2023
# Human: J Dunphy
#
# Use:  Track ip addresses with a date count.
#       ip addresses can then be exported to a file which can be used 
#       for milters, ipsets, etc.
#
# Purpose: We have a blacklist that tracks ip's attempting delivery to spam bait email addresses.
#       Those ip's are added to a list that a milter will then tag subsequent connections from matching
#       ip's with a header that our spam engines can later use in their scoring.
#
#       This program allows us to choose how many years or days we want this list to be.
#
#

use strict;
use warnings;
use DBI;
use Getopt::Long;

my $db_file = "ip_addresses.db";

my ($import_file, $add_ip, $export_file, $newer_than, $help);

GetOptions(
    "import=s"  => \$import_file,
    "add=s"     => \$add_ip,
    "export=s"  => \$export_file,
    "newer=s"   => \$newer_than,
    "help"      => \$help,
) or die("Error in command line arguments\n");

sub usage {
    print "Usage: $0 [options]\n";
    print "Options:\n";
    print "  --import <file>          Import a file containing a list of IP addresses (1 per line)\n";
    print "  --add <ip_address>       Add a single IP address to the list\n";
    print "  --export <file>          Export IP addresses that are newer than specified duration to a file (default: 10 days)\n";
    print "  --newer <duration>       Duration in seconds, minutes, hours, days, weeks, months, or years (e.g. '10 days', '2 weeks')\n";
    print "  --help                   Display this help message\n";
    exit;
}

usage() if $help;

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", { RaiseError => 1, AutoCommit => 1 });

$dbh->do("CREATE TABLE IF NOT EXISTS ip_addresses (ip TEXT PRIMARY KEY, timestamp DATETIME DEFAULT (datetime('now')));");

sub import_ips {
    open my $fh, '<', $import_file or die "Cannot open $import_file: $!";
    while (my $ip = <$fh>) {
        chomp $ip;
        eval { $dbh->do("INSERT OR REPLACE INTO ip_addresses (ip) VALUES (?)", undef, $ip) };
    }
    close $fh;
}

sub add_ip_address {
    eval { $dbh->do("INSERT OR REPLACE INTO ip_addresses (ip) VALUES (?)", undef, $add_ip) };
}

sub export_ips {
    $newer_than = '10 days' unless defined $newer_than;
    my $duration = $newer_than =~ /^\d/ ? "+$newer_than" : $newer_than;
    my $interval = "strftime('%s', 'now') - strftime('%s', timestamp)";
    my $sth = $dbh->prepare("SELECT ip FROM ip_addresses WHERE $interval <= ?");
    $sth->execute($duration);
    open my $fh, '>', $export_file or die "Cannot open $export_file: $!";
    while (my ($ip) = $sth->fetchrow_array()) {
        print $fh "$ip\n";
    }
    close $fh;
}

import_ips() if $import_file;
add_ip_address() if $add_ip;
export_ips() if $export_file;

$dbh->disconnect;

