#!/usr/bin/perl

#
# Very Fast: reverse lookup (ASYNC lookups)
#    < 1 sec for 129 look ups
#
# usage: blcheck.pl X.X.X.X Y.Y.Y.Y
#        cat list | blcheck.pl
#        check_attacker.pl --pstatus=400 --iplist | blcheck.pl
#
# Proof of concept.
#
# Author: Jim Dunphy jad AT aesir.com (5/1/2019)
#
# CAVEAT: requires separate installation of Net::DNS::Native and AnyEvent via cpan.
#    cpan> install /OLEG/Net-DNS-Native-0.20.tar.gz/ 
#    cpan>  install /MLEHMANN/AnyEvent-7.15.tar.gz/ 
#

use Net::DNS::Native;
use AnyEvent;
use Socket;
#use Data::Dumper qw(Dumper);

#register at http://www.projecthoneypot.org/httpbl_api.php 
# to obtain an API-key (free)
$key="DEFINE KEY";


# from command line or via STDIN
if (@ARGV) {
   @ips = @ARGV;
}
else 
{
   # do some cleanup just in case
   while(my $ip = <STDIN>){
      chomp $ip;
      next if ($ip !~ qr/^(?!(\.))(\.?(\d{1,3})(?(?{$^N > 255})(*FAIL))){4}$/);
      push(@ips, $ip);
   }
}

#print Dumper \@ips;

my $dns = Net::DNS::Native->new;
my $cv = AnyEvent->condvar;
$cv->begin;
    
#for my $host ('217.182.143.93', '61.219.11.153', '134.119.189.29') 
for my $host (@ips) 
{
   my $target_IP = join('.', reverse split(/\./, $host)).".cbl.abuseat.org";
   #my $target_IP = "$key.".join('.', reverse split(/\./, $host)).".dnsbl.httpbl.org";
   #print "$target_IP\n";

   my $fh = $dns->inet_aton($target_IP);
   $cv->begin;
        
   my $w; $w = AnyEvent->io(
      fh   => $fh,
      poll => 'r',
      cb   => sub {
         my $ip = $dns->get_result($fh);
         print "$host ".inet_ntoa($ip),"\n" if ($ip);

         $cv->end;
         undef $w;
         }
     )
}
    
$cv->end;
$cv->recv;
