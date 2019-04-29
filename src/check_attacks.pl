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

#========================================================================
# SECTION -  Modules, Variables, etc.
#========================================================================
use Term::ANSIColor;
use Data::Dumper qw(Dumper);
use Getopt::Long;

%ip_list = ();  #ip list
%PossibleStatusCodes = ();

#========================================================================
# SECTION -  FUNCTIONS
#========================================================================
# Displays program usage

$PROJECT="https://github.com/JimDunphy/ZimbraScripts/blob/master/src/check_attacks.pl";
$VER="0.5";

sub version() {
  print "$PROJECT\nv$VER\n";
  exit;
}

sub usage {

print <<"END";
usage: % check_attacker.pl 
        [--fcolor=<color name (i.e. RED)>]
        [--srcip=<ip address>]
        [--fail=<user|ip|none>]
        [--localUser ]
        [--IPlist ]
	[--statuscnt]
	[--usertype=<attacker|local|all>
	[--pstatus=<regex of status codes>
        [--help]
        [--version]
    where:
        --srcip|sr: print only records matching ip addresses
	--statuscnt: prints out the count for each status return code found
        --help|h: this message
examples:  (-- or - or first few characters of option so not ambigous)
         % check_attacker.pl -srcip 10.10.10.1      #only this ip address
         % check_attacker.pl -srcip  '10.10.10.1|20.20.20.2'      #only these ip addresses
         % check_attacker.pl -statuscnt  #print status codes
         % check_attacker.pl --statuscnt  #print status codes  #same
         % check_attacker.pl --localUser #include local users accounts
         % check_attacker.pl --IPlist   # print list of ips
         % check_attacker.pl --IPlist --ipset  # print list of ips in ipset format
         % check_attacker.pl --localUser --IPlist   # print list of local ips used by local users
         % check_attacker.pl --IPlist --ipset  | sh # install ip's into ipset 
         % check_attacker.pl --initIPset  # show how to create ipset 
         % check_attacker.pl -fc RED  #change color 
         % check_attacker.pl --usertype=local  # print out strings of only local users
         % check_attacker.pl --pstatus='4..'  # print out only those requests with a code of 4XX (ie 403, 404, 499)
         % check_attacker.pl --usertype=all --pstatus='403|500'  # print out only those requests with a code of 403 or 500 for all types (local & attacker)
END
    exit 0;
}


sub printIPs {
   my ($ip) = @_;

   # print local ips
   if ($localUser) 
   {
      print "$ip\n" if ($ip_list{$ip}{'ourUser'});
      return;
   }
   else  # only remote ips
   {
       next if (exists $ip_list{$ip}{'ourUser'} && !$localUser);
       print "$ip\n" if (!$ipset);
       print "ipset add blacklist24hr $ip -exists\n" if ($ipset); 
       return;
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

   for $codes (sort keys %PossibleStatusCodes )
   {
      print "Codes $codes Total: $PossibleStatusCodes{$codes}{'count'}\n";
   }
   exit;
}


sub setlists {
    my ($attacker, $request, $uagent, $status, $upstream, $remuser) = @_;

    #%%% STEP 1 - our own users
    $ip_list{$attacker}{'ourUser'} = 1 if ($request =~ m#(jsessionid|adminPreAuth|apple-touch-icon)#);
    $ip_list{$attacker}{'ourUser'} = 1 if (($status == '200') && ($request =~ m#(ActiveSync\?User=)#));

    # noise (filter some of this out)
    next if ($request =~ /favicon/i);
    if ($status == '404')
    {
       next if ($request =~ /EWS/i);
       next if ($request =~ /apple-touch/i);
    }

    #%%%  need to investigate upstream still... possible hacking

    # definitely hacking... 
    ++$ip_list{$attacker}{'hack'} if (($request =~ m#^-#) || ($uagent =~ m#^-$#));

    # no need for HTTP/1.1, etc on request
    $request =~ s#HTTP/.*##i if ($request =~ /http/i);  

    my $i = ++$ip_list{$attacker}{'count'} - 1;
    $ip_list{$attacker}{'request'}[$i] = $request; # count of requests per ip
    $ip_list{$attacker}{'status'}[$i] = $status;
    $ip_list{$attacker}{'uagent'}[$i] = $uagent;

    # Store off status code counts aware of usertype request. This is for the printCode
    $PossibleStatusCodes{$status};
    ++$PossibleStatusCodes{$status}{'count'};

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

# Pretty clear - output a big line
sub drawline {
  print "\n------------------------------------------------------------------------------------------------------------\n";
  return;
}
  

#========================================================================
# SECTION -  GET input parameters
#========================================================================
# Get the command line parameters for processing
    my $fcolor = 'CYAN';    # GREEN, etc
    my $srcip = '@';
    my $failtype = 'all';   #default failure behavior (user|ip|none)
    my $statuscnt = 0;      #default not to print status codes
    my $pstatus = '';       #default not to print status codes
    local $localUser = 0;   #default not to include localusers 
    my $IPlist = 0;         #print ip addresses
    local $ipset = 0;       #print local ip addresses in ipset format 
    my $initIPset = 0;      #show how to create an ipset
    my $help, $dbug = 0;
    local $usertype = 'attacker';
    &GetOptions("fcolor=s" => \$fcolor,  # %%% ToDo
                "srcip=s" => \$srcip,
                "debug" => \$dbug,       # turn on debugging
                "localUser" => \$localUser,  # turn on localuser
                "IPlist" => \$IPlist,  # print out ip's in a list format
                "ipset" => \$ipset,  
                "initIPset" => \$initIPset,  
                "pstatus:s" => \$pstatus,  # turn on status codes
                "statuscnt" => \$statuscnt,  # print out count of status codes
                "usertype=s" => \$usertype,  # print out count of status codes
                "version" => \&version,
                "help" => \$help);

    # call Help if parameters do not meet expected values or help is requested
    $usertype = 'attacker' if $usertype eq '';
    usage() if($help || ($usertype !~ m/^attacker|local|all$/));


#========================================================================
# SECTION -  PARSE audit.log files & process accordingly
#========================================================================
chdir "/opt/zimbra/log";

for (glob 'nginx.access.log*') {

  $nginx_log = $_ eq 'nginx.access.log' ? 1 : 0;
  #print "Opening file $_";
  open (IN, sprintf("zcat -f %s |", $_))
       or die("Can't open pipe from command 'zcat -f $nginx_log' : $!\n");

  while (<IN>)
  {

   my($ip, $port, $remuser, $date, $request, $status, $bytes, $referrer, $uagent, $upstream) = /^([^:\s]+):?(\d*)\s+(?:-\s)([^\s]+)\s+\[([^\s+]+)[^\]]+\]\s+"([^"]*)"\s+(\d+)\s(\d+)\s+"([^"]*)"\s"([^"]*)"\s+"([^"]*)"/is;
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

   setlists($ip, $request, $uagent, $status, $upstream, $remuser);

  } 
  close (IN);

}

#========================================================================
# SECTION -  PRINT / MAIN
#========================================================================
#debug
#print Dumper \%ip_list;
#print Dumper \%PossibleStatusCodes;

   #drawline();
   printCodes if $statuscnt;	#print status codes
   printIPsetInit if ($initIPset);      # show how to build an ipset   

#debug
# Print out the arrays by attackers ip address. Flag failures.
for $attacker (sort keys %ip_list )
{
#debug
#print "attacker is $attacker\n",next if ($debug);

   printIPs($attacker),next if($IPlist); #print ips

   # don't print local/accepted users if only looking for attackers
   next if ($ip_list{$attacker}{'ourUser'} && ($usertype eq 'attacker'));
   next if (($usertype eq 'local') && !$ip_list{$attacker}{'ourUser'});

   #next if ($ip_list{$attacker}{count} <= 2);		# don't show 1 or 2 times only

  # Skip this attacker, if -s parameter is given and attacker is not in search string
  next if ($attacker !~ m#$srcip# && $srcip != '@');

#debug
#print Dumper \%ip_list->{$attacker}; 
   my $count = $ip_list{$attacker}{'count'};
   my $hitstatus = 0;
   my $hack = 0;
   $hack = 25 if (!$ip_list{$attacker}{'ourUser'});
   $hack = 100 if (exists $ip_list{$attacker}{'hack'});
  
   # print the requests per ip address
   for ($i=0; $i < $#{$ip_list{$attacker}{'request'}}+1; $i++)
   {
       my $request = $ip_list{$attacker}{'request'}[$i];
       my $uagent = $ip_list{$attacker}{'uagent'}[$i];
       my $status = $ip_list{$attacker}{'status'}[$i];

       next if (($pstatus ne '') && ($status !~ /$pstatus/));
       $hitstatus++;

       $request = 'stealth request - exploit attemped' if ($request =~ m#^-$#);
       $uagent = 'bot' if ($uagent =~ m#^-$#);

#debug
#print Dumper $request;
#print "attacker $attacker request is $request\n"; next;

        printf ("\t[%4d] %s %s", $status,$request, $uagent);
        print color('reset');
        printf ("\n");
    } 

    my $msg = sprintf("%d failed - Score %d\% ", $count, $hack); 
    $msgcolor = $hack > 50 ? "RED" : "CYAN";
    printresults("RED", "BOLD", "Attacker from $attacker", $msgcolor, $msg) if $hitstatus;

    drawline() if $hitstatus;
}
   printf ("\n");
   print color('reset');  # make sure we clean up
