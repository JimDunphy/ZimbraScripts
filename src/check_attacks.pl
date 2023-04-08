#!/usr/bin/perl
#
# Author: Jim Dunphy <jad aesir.com>
# License (ISC): It's yours. Enjoy
# Date: 04/28/2019
#
# usage: check_attack.pl [Options]
#
# ======================================================================
#
# NOTES: ourUser  --- need to customize to each install to provide
#                     best guess at what external attackers are
#                     Search for STEP 1 in code to customize
# 
# Nov 12, 2022 - getting better. Very little customizations needed anymore
#

#========================================================================
# SECTION -  Modules, Variables, etc.
#========================================================================
use Term::ANSIColor;
use Data::Dumper qw(Dumper);
use Getopt::Long;

package main;

use diagnostics;
use warnings;
use strict;

my %ip_list = ();  #ip list
my %PossibleStatusCodes = ();
my $logDir="/opt/zimbra/log";
my $nginx_access_log="nginx.access.log*";

#========================================================================
# SECTION -  BOTS (listed in user agent) and their bait
#========================================================================
my $bot_list = "zgrab|Bot|python|curl|lwp|wget|http|parser|cyberwarcon";
my $bot_bait = "logon\.aspx|jnamespaces|wp-includes|pods|\.jsp";
my $san_list = '';

my $pstatus = '';       #default not to print status codes
my $ipset = 0;       #print local ip addresses in ipset format 
my $fail2ban = 0;       #print ip addresses in fail2ban format 
my $fcolor = 'CYAN';    # GREEN, etc
my $display = 'uagent'; # default user agent
my $srcip = '@';
my $search = '';
my $statuscnt = 0;      #default not to print status codes
my $localUser = 0;   #default not to include localusers 
my $IPlist = 0;         #print ip addresses
my $initIPset = 0;      #show how to create an ipset
my ($help, $debug) = 0;
my $usertype = 'attacker';

# pre-declare Globals
use vars qw( $debug $localUser $pstatus $fail2ban $ipset $search $display $attacker $usertype $srcip $msgcolor $nginx_log );

#========================================================================
# SECTION -  FUNCTIONS
#========================================================================
# Displays program usage

my $PROJECT="https://raw.githubusercontent.com/JimDunphy/ZimbraScripts/master/src/check_attacks.pl";
my $VER="0.9.01";

sub version() {
  print "wget $PROJECT\n#v$VER\n";
  exit;
}

sub usage {

print <<"END";
usage: % check_attacker.pl 
        [--fcolor=<color name (i.e. RED)>]
        [--srcip=<ip address>]
        [--search='regex of search']
        [--localUser ]
        [--logDir=`pwd` ]
        [--file=nginx.access.log ]
        [--IPlist ]
        [--ipset ]
        [--fail2ban ]
	[--statuscnt]
	[--display="date|upstream|bytes|port|referrer]
	[--usertype=<attacker|local|all>
	[--pstatus=<regex of status codes>
        [--help]
        [--version]
    where:
        --srcip|src: print only records matching ip addresses
        --search|sea: print all requests from an ip that has a search term hit
	--statuscnt: prints out the count for each status return code found
        --help|h: this message
examples:  (-- or - or first few characters of option so not ambigous)
         % check_attacker.pl --srcip 10.10.10.1      #only this ip address
         % check_attacker.pl --srcip  '10.10.10.1|20.20.20.2'      #only these ip addresses
         % check_attacker.pl --search  'python|POST'     # if an ip had search term, all requests printed for ip
         % check_attacker.pl --search  '\.jsp|\.php|bot' # if an ip had search term, all requests printed for ip
         % check_attacker.pl --statuscnt  #print status codes
         % check_attacker.pl --localUser #include local users accounts
         % check_attacker.pl --IPlist   # print list of ips
         % check_attacker.pl --IPlist --localUser   # print list of ips from local users
         % check_attacker.pl --IPlist --ipset  # print list of ips in ipset format
         % check_attacker.pl --IPlist --fail2ban  # print list of ips in fail2ban format
         % check_attacker.pl --IPlist -pstatus='40.' --ipset  # print list of ips in ipset format with status code 400..409
         % check_attacker.pl --IPlist -pstatus='40.' --fail2ban  # print list of ips in fail2ban format with status code 400..409
         % check_attacker.pl --localUser --IPlist   # print list of local ips used by local users
         % check_attacker.pl --IPlist --ipset  | sh # install ip's into ipset 
         % check_attacker.pl --IPlist --fail2ban  | sh # install ip's into fail2ban 
         % check_attacker.pl --initIPset  # show how to create ipset 
         % check_attacker.pl -fc RED  #change color 
         % check_attacker.pl --usertype=local  # print out strings of only local users
         % check_attacker.pl --pstatus='4..'  # print out only those requests with a code of 4XX (ie 403, 404, 499)
         % check_attacker.pl --usertype=all --pstatus='403|500'  # print out only those requests with a code of 403 or 500 for all types (local & attacker)
         % check_attacker.pl --display=date      # default is to display the user agent
         % check_attacker.pl --display=referrer  # default is to display the user agent
         % check_attacker.pl --version | sh      # pull the latest verstion with wget to current working directory

    Status Codes - https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
END
    exit 0;
}


# ./check_attacks.pl --iplist --pstatus='40.'
# ./check_attacks.pl --iplist --pstatus='40.' --ipset
# ./check_attacks.pl --iplist --ipset
# ./check_attacks.pl --iplist 
# ./check_attacks.pl --iplist --localUser

sub printIPs {

   for my $ip (sort keys %ip_list ) {
       # print local ips
       if ($localUser) {
          print "$ip\n" if  $ip_list{$ip}{'ourUser'} ;
       }
       elsif (!exists $ip_list{$ip}{'ourUser'})   # only non-local IPs from here forward
       {
	  my $smatch = 0;
          # print by status codes
          if ($pstatus ne '')
          {
               # loop through the status array for this ip address
               for (my $i=0; $i < $#{$ip_list{$ip}{'request'}}+1; $i++)
               {
                  my $status = $ip_list{$ip}{'status'}[$i];
                  $smatch = 1, last if ($status =~ /$pstatus/);
                }
          }
          # print by search
          elsif ($search ne '')
          {
                 $smatch = 1 if $ip_list{$ip}{'tag'};
          } else {
                 $smatch = 1;
          }
         # print all the attacking ip's
         print "ipset add blacklist24hr $ip -exists\n" if ($ipset && $smatch);
         print "fail2ban-client set zimbra-nginx $ip\n" if ($fail2ban && $smatch);
         print "$ip\n" if ($smatch && !$fail2ban && !$ipset);

         #($ipset ?  print "ipset add blacklist24hr $ip -exists\n" : print "$ip\n") if ($smatch);
         #($fail2ban ?  print "fail2ban-client set zimbra-nginx $ip\n" : print "$ip\n") if ($smatch);
      }
   }
}

sub printIPsetInit {
print <<"END";

# - ipset create should be executed only once
# - It requires that you have a single rule like this defined
#
# % sudo iptables -A INPUT -m set --set blacklist24hr src -j DROP
#
# Example using centos/rhel /etc/sysconfig/iptables
# Syntax for /etc/sysconfig/iptables 
#    -A INPUT -m set --match-set blacklist24hr src -j DROP
# Note: Any ip added to the ipset blacklist24hr will expire in 24 hours
# - use the --ipset --iplist options to format ip's into ipset add commands
# reference: http://ipset.netfilter.org/index.html

ipset create blacklist24hr hash:ip hashsize 4096 timeout 86400
END
   exit;
}

sub printCodes {

   for my $codes (sort keys %PossibleStatusCodes )
   {
      print "Codes $codes Total: $PossibleStatusCodes{$codes}{'count'}\n";
   }
   exit;
}


sub setlists {
    my ($ip, $port, $remuser, $date, $request, $status, $bytes, $referrer, $uagent, $upstream) = @_;

    #%%% BEGIN STEP 1 
    # noise (filter some of this out) - this won't be saved.
    return if ($uagent =~ /uptimerobot/i);	# self-induced - If you use a bot to measure uptime 

    return if ($request =~ /favicon/i);
    # %%% GET / HTTP is a problem with a 200 status. Both users and bots look the same. Need additional information so noise for now
    return if (($status eq '200') && ($request =~ m#GET\s+/\s+HTTP#i)); # noise for now
    if ($status =~ m#401|403|404|499|500|502#)
    {
       return if ($request =~ /EWS/i);
       return if ($request =~ /Briefcase/i);
       return if ($request =~ m#service/home/#i);
       return if ($request =~ /apple-touch/i);
       return if ($request =~ /ActiveSync/i);	# %%% can happen with 401/403/499/500/502 codes

    }

    #  Normal Zimbra user stream found with 
    #  check_attack --usertype=local
    $ip_list{$ip}{'ourUser'} = 1 if (($status eq '200') && ($request =~ m#(jsessionid|adminPreAuth|st=conversation)#));
    $ip_list{$ip}{'ourUser'} = 1 if (($status eq '200') && ($request =~ m#(ActiveSync)#i));
    $ip_list{$ip}{'ourUser'} = 1 if ((($status eq '200') && $request =~ /POST/) && ($request =~ m#soap|NoOpRequest#i));
    $ip_list{$ip}{'ourUser'} = 1 if (($status =~ m#207|200#) && $request =~ m#REPORT|PROPFIND#i && $request =~ m#dav|users#i);
    # more general case with service/soap
    $ip_list{$ip}{'ourUser'} = 1 if ((($status eq '200') && $request =~ /POST/) && ($request =~ m#service/soap#));


    #%%% END STEP 1 - our own users

    #%%%  need to investigate $upstream still... possible hacking

    # skip this attacker, if -search paramater is given 
    # check_attacks.pl --search 'POST|Auto'
    # check_attacks.pl --display=date --search '24/May|Post'
    # check_attacks.pl -search '\.jsp|\.php' 
    if(($search ne  '') && (($request.$uagent.$date.$referrer) =~ m#$search#i)) { 
        $ip_list{$ip}{'tag'} = 1;
    }

    # definitely hacking... 
    ++$ip_list{$ip}{'hack'} if (($request =~ m#^-#) || ($uagent =~ m#^-$#));
    ++$ip_list{$ip}{'hack'} if ($uagent =~ m#$bot_list#i);
    ++$ip_list{$ip}{'hack'} if ($request =~ m#$bot_bait#i);
    ++$ip_list{$ip}{'hack'} if ($request !~ m#($san_list)#i);
    ++$ip_list{$ip}{'hack'} if ($status == '400'); # malformed requests
    ++$ip_list{$ip}{'hack'} if ($request =~ m#GET\s+/zimbra\s+HTTP#); # malformed requests

    # clean up if data is missing
    $request = 'stealth request - exploit attemped' if ($request =~ m#^$#);
    $uagent = 'bot' if ($uagent =~ m#^-$#);

    # no need for HTTP/1.1, etc on request
    $request =~ s#HTTP/.*##i if ($request =~ /http/i);  

    my $i = ++$ip_list{$ip}{'count'} - 1;
    $ip_list{$ip}{'request'}[$i] = $request; # count of requests per ip
    $ip_list{$ip}{'status'}[$i] = $status;

    # reuse this second field to display others columns
    $ip_list{$ip}{'uagent'}[$i] = $uagent;   # default
    $ip_list{$ip}{'uagent'}[$i] = $date if ($display =~ m#date#i);
    $ip_list{$ip}{'uagent'}[$i] = $upstream if ($display =~ m#upstream#i);
    $ip_list{$ip}{'uagent'}[$i] = $bytes if ($display =~ m#bytes#i);
    $ip_list{$ip}{'uagent'}[$i] = $port if ($display =~ m#port#i);
    $ip_list{$ip}{'uagent'}[$i] = $referrer if ($display =~ m#referrer#i);


    # Store off status code counts aware of usertype request. This is for the printCode
    $PossibleStatusCodes{$status}{'count'}++;

#print Dumper \%ip_list;

    return;
}

# Print results out
sub printresults {
    my($ucolor, $uattr, $user, $msgcolor, $msg) = @_;

    print color($ucolor, $uattr), " "; 
    printf "%-47s", $user; 
    print color('reset'); 
    print color($msgcolor), $msg;
    print color('reset');

    return;
}

sub printRequests {

#debug
#print Dumper \%ip_list;

	# Print out the arrays by attackers ip address. Flag failures.
	for $attacker (sort keys %ip_list )
	{
	   # don't print local/accepted users if only looking for attackers
	   next if (($ip_list{$attacker}{'ourUser'} && ($usertype eq 'attacker'))
	         || (($usertype eq 'local') && !$ip_list{$attacker}{'ourUser'}));

	   # Skip this attacker, if -srcip parameter is given and attacker is not in search string
           # check_attacks.pl --srcip '61.177.26.58|159.69.81.117|45.112.125.139|185.234.217.185|185.234.218.228'
	   next if ($attacker !~ m#$srcip# && $srcip ne '@');

           # don't print attackers that didn't match search
           next if (! exists $ip_list{$attacker}{'tag'} && $search ne '');

	   my $hitstatus = 0;
	   my $hack = 0;   # %%% The next 3 lines should be moved to setlists
	   $hack = 25 if (!$ip_list{$attacker}{'ourUser'});
	   $hack = 100 if (exists $ip_list{$attacker}{'hack'});
	  
	   # print the requests per ip address
	   for (my $i=0; $i < $#{$ip_list{$attacker}{'request'}}+1; $i++)
	   {
	       my $request = $ip_list{$attacker}{'request'}[$i];
	       my $uagent = $ip_list{$attacker}{'uagent'}[$i];
	       my $status = $ip_list{$attacker}{'status'}[$i];

               # printing by status code 
	       next if (($pstatus ne '') && (!($status =~ /$pstatus/)));
	       $hitstatus++;

               printf ("\t[%4d] %s %s", $status,$request, $uagent);
               print color('reset');
               printf ("\n");
	   } 

	   if ($hitstatus)
	   {
	      my $msg = sprintf("%d Requests - Score %d%% ",  $ip_list{$attacker}{'count'}, $hack); 
	      $msgcolor = $hack > 50 ? "RED" : "CYAN";
	      my $userstr = $hack ? "Attacker from " : "Zimbra User from ";
	      printresults("RED", "BOLD", "$userstr $attacker", $msgcolor, $msg);
	      drawline();
	   }

	}
}

# Pretty clear - output a big line
sub drawline {
  print "\n------------------------------------------------------------------------------------------------------------\n";
  return;
}

sub getSanList {

   #certificate names
   open my $fh, "-|","openssl s_client -connect 127.0.0.1:443 < /dev/null 2> /dev/null | openssl x509 -noout -text | grep DNS:" or die $!;

   my ($san);
   $san_list=<$fh>;

   $san_list =~ s#DNS:##gp;
   $san_list =~ s#,#|#gp;
   $san_list =~ s#\s+##gp;
   $san_list =~ s#\.#\\.#gp;
   $san_list =~ s#\*#\\*#gp;	#wild card domains

   close($fh);
}

#========================================================================
# SECTION -  GET input parameters
#========================================================================
# Get the command line parameters for processing
    &GetOptions("fcolor=s" => \$fcolor,  # %%% ToDo
                "display=s" => \$display,
                "srcip=s" => \$srcip,
                "file=s" => \$nginx_access_log,
                "logDir=s" => \$logDir,
                "search=s" => \$search,
                "debug" => \$debug,       # turn on debugging
                "localUser" => \$localUser,  # turn on localuser
                "IPlist" => \$IPlist,  # print out ip's in a list format
                "ipset" => \$ipset,  
                "fail2ban" => \$fail2ban,  
                "initIPset" => \$initIPset,  
                "pstatus:s" => \$pstatus,  # turn on status codes
                "statuscnt" => \$statuscnt,  # print out count of status codes
                "usertype=s" => \$usertype,  # print out count of status codes
                "version" => \&version,
                "help" => \$help);

    # call Help if parameters do not meet expected values or help is requested
    $usertype = 'attacker' if $usertype eq '';
    usage() if($help || ($usertype !~ m/^attacker|local|all$/));

# determine what are legal names based on the certificate - used to determine bot vs user
getSanList;


#========================================================================
# SECTION -  PARSE audit.log nginx_access_logs & process accordingly
#========================================================================
#chdir "/opt/zimbra/log";
chdir "$logDir";

#for (glob 'nginx.access.log*') {
#for (glob 'nginx.access.log') {
for (glob $nginx_access_log) {

  $nginx_log = $_ eq 'nginx.access.log' ? 1 : 0;
  #print "Opening nginx_access_log $_";
  open (IN, sprintf("zcat -f %s |", $_))
       or die("Can't open pipe from command 'zcat -f $nginx_log' : $!\n");

  while (<IN>)
  {

   my($ip, $port, $remuser, $date, $request, $status, $bytes, $referrer, $uagent, $upstream) = /^([^:\s]+):?(\d*)\s+(?:-\s)([^\s]+)\s+\[([^\s+]+)[^\]]+\]\s+"([^"]*)"\s+(\d+)\s(\d+)\s+"([^"]*)"\s"([^"]*)"\s+"([^"]*)"/is;

   next if (! defined $ip );		# have seen double ip entries in a log so we punt

#print "ip [$ip] ";
#print "remuser [$remuser] ";
#print "port is [$port] ";
#print "date is [$date] ";
#print "request is [$request] ";
#print "status is [$status] ";
#print "bytes is [$bytes] ";
#print "user_agent is [$uagent] ";
#print "$ip ip referrer is [$referrer] ";
#print "upstream is [$upstream] ";
#print "\n"; next;

   setlists($ip, $port, $remuser, $date, $request, $status, $bytes, $referrer, $uagent, $upstream);

  } 
  close (IN);

}


#========================================================================
# SECTION -  PRINT / MAIN
#========================================================================
#debug
#print Dumper \%ip_list;
#print Dumper \%PossibleStatusCodes;

  
# MAIN LOGIC
   if($statuscnt) {
	printCodes;
    } elsif ($initIPset) {
	printIPsetInit;
    } elsif ($IPlist) {
	printIPs;
        exit;		# we don't want to add garbage with reset if part of a pipeline
    } else {
        printRequests;
    }

   # finished / clean up
   printf ("\n");
   print color('reset');  # make sure we clean up

# END
