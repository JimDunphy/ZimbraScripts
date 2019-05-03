#!/usr/bin/perl

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/bin
#
# # Author: Jim Dunphy <jad aesir.com>
# License (ISC): It's yours. Enjoy
# Date: 04/28/2019
#
# Example program to allow ip blocking against attackers using ipsets.
# Will put any ip addresses into a blacklist to expire in 1 day if it matches some
# number of bad to times. Can accept multiple files.
#
# usage: Choose 1 of either modes to run it.
#
# debug mode (parse files):
#    % zcat -f /opt/zimbra/log/nginx.access* | build_mail_ipset.pl
#    % grep '03/May' /opt/zimbra/log/nginx.access.log | build_mail_ipset.pl
#    % check_attacks.pl --pstatus=400 | build_mail_ipset.pl
# daemon mode (tail mode) needs to be running as root:
#    # build_mail_ipset.pl -t
#
# CAVEAT: To add an ip address into the kernel ipset requires this the ipset command operate as root.
# 
# examples: 
#  %  sudo build_mail_ipset.pl -t &
#  %  zcat -f /opt/zimbra/log/nginx.access* | build_mail_ipset.pl 
#     if you like the output then executed it
#  %  zcat -f /opt/zimbra/log/nginx.access* | build_mail_ipset.pl | sh
#
# Configure by following STEP0 .. STEP3 below
#
# Note: I do not run this program as I have more sosphisticated methods.
#       I show an example using 400 status codes but other logic could be
#       added to make this more realistic. 
#

#-------------------------------------------------
# STEP0:
#
# This program requires the Multi File Tail
# Location:
# http://search.cpan.org/~atripps/File-Tail-Multi-0.1/Multi.pm
# https://metacpan.org/pod/release/ATRIPPS/File-Tail-Multi-0.1/Multi.pm
#
# To install perl Multi tail modules
# % wget https://cpan.metacpan.org/authors/id/A/AT/ATRIPPS/File-Tail-Multi-0.1.tar.gz
# % tar zxvf File-Tail-Multi-0.1.tar.gz
# % cd File-Tail-Multi-0.1
# % perl Makefile.pl
# % sudo make install
#
#-------------------------------------------------

# STEP1: Configuration

#  Force failure if they don't configure this.
#$TRUSTED="127.0.0.1|X.X.X.X|Y.Y.Y.Y";
$TRUSTED=CONFIGURE_ME
# how many chances they get in 24 hours before we add them to an ipset
$badLookUps=5;
#$badLookUps=1;

# STEP2: Configure/install ipset. Create ipset, Add a single rule.
# % sudo ipset create blacklist24hr hash:ip hashsize 4096 timeout 86400
# % sudo iptables -A INPUT -m set --set blacklist24hr src -j DROP
#      or  (don't show as filtered for scans)
# % sudo iptables -A INPUT -m set --set blacklist24hr src -j REJECT --reject-with tcp-reset
#

use Sys::Syslog;
use File::Tail::Multi;

#default is to use stdin
my($useSTDIN) = 1;

#use tail instead
if (shift(@ARGV) =~ "-t")
{
   $useSTDIN = 0;
}

# pipeline
sub ReadStdin {

   while(<STDIN>) {
       ProcessLine($_);
   }
}

# read build-in logfiles
sub ReadTail {

$tail=File::Tail::Multi->new (
     OutputPrefix => "f",
     RemoveDuplicate => "1",
     NumLines => 1,
     #Files => ["/var/log/all.log","/var/log/httpd/access_log","/vendor/apache/clients/www.example.com/logs/www.log"]
     Files => ["/opt/zimbra/log/nginx.access.log"]
);

# watch multiple log files and process lines of interest
        while(1) {

           my $rFD = $tail->read;

           foreach my $FH ( @{$rFD->{FileArray}} ) {
                   foreach my $LINE ( @{$FH->{LineArray}} ) {
                           ProcessLine($LINE);
                   }
           }
           sleep 30;
        }
}

# syslog goes to mail.info on ipset addition
openlog("build_mail_ipset.pl", 'ndelay', 'mail');

%ip_list = ();


# filter line and find ip's to blacklist
sub ProcessLine {
  my($line) = @_;
  $_ = $line;

   # parse (specific to zimbra nginx.access.log format)
   my($ip, $port, $remuser, $date, $request, $status, $bytes, $referrer, $uagent, $upstream) = /^([^:\s]+):?(\d*)\s+(?:-\s)([^\s]+)\s+\[([^\s+]+)[^\]]+\]\s+"([^"]*)"\s+(\d+)\s(\d+)\s+"([^"]*)"\s"([^"]*)"\s+"([^"]*)"/is;

   # Never add our own trusted ip space.
   if (($ip =~ m/$TRUSTED/)) { next };

   # track by ip address, status, and a count
   ++$ip_list{$ip}{$status}{'count'};
   #print "attacker $ip and count is $ip_list{$ip}{$status}{'count'}\n";

   # Example of blocking any ip that issues too many 400's that are larger than our badLookUps threashold
   if ($ip_list{$ip}{'400'}{'count'} > $badLookUps)
   {
      BlockIP($ip, $ip_list{$ip}{'400'}{'count'});
   }
} 

# log ip and add to blacklist
sub BlockIP {
   my ($ip,$count) = @_;

   #printf ("[%4d] - %s\n", $count,$ip);
   printf ("ipset add blacklist24hr %s -exists\n",$ip);
#STEP 3 (uncomment this out)
#   system("ipset add blacklist24hr $ip -exist");
#   syslog('info',"ipset add blacklist24hr $ip");
}

# main()
if ($useSTDIN)
{
        ReadStdin;
}
else
{
        ReadTail;
}

exit;
