#!/usr/bin/perl
#
# Author: Jim Dunphy <jad aesir.com>
# License (ISC): It's yours. Enjoy
# Date: 10/9/2015
#   Update on feedback from Lapsy from forums.zimbra.com 10/13/2018
#
# usage: check_login.pl [Options]
#
# ======================================================================

#========================================================================
# SECTION -  Modules, Variables, etc.
#========================================================================
use Term::ANSIColor;
use Data::Dumper qw(Dumper);
use Getopt::Long;
use Socket qw( inet_aton AF_INET );

%ip_list = ();  #ip list
%fip_list = ();   #failed ip list

#========================================================================
# SECTION -  FUNCTIONS
#========================================================================
# Displays program usage
sub usage {

print <<"END";
usage: % check_login.pl 
        [--color=<color name (i.e. RED)>]
        [--srchuser=<username>]
        [--fail=<user|ip|none>]
        [--gethost=<all|fail|none>]
        [--help]
    where:
        --color|c: color to be used for FAILED login message information
        --srchuser|s: print ONLY the logins/failed logins for <username>
        --fail|f: if 'user': print ONLY users who have failed logins. If 'ip': print ONLY the failed login attempts. 'none': print all records regardless if failure
        --gethost|g: values of 'all', 'fail' or 'none'. Perform a GETHOSTBYADDR for all IPs, only on FAILED login attempts, or don't perform this action (none)
        --help|h: this message\n";
example: % check_login.pl -f=user    #only the accounts with failed logins
         % check_login.pl -f ip      #only the accounts and the ip that failed
         % check_login.pl -fail=ip   # same as above
         % check_login.pl --fail ip  # same as above
         % check_login.pl -f ip -h   #list only ip's that failed for accounts resolve ip to domain name
         % check_login.pl -g fail    #list only accounts that had a failed login
         % check_login.pl -g all     #list all accounts and resolve ip to domain name
         % check_login.pl -c RED -f ip #change color and list only failed ip's     
         % check_login.pl -s user -f ip -g fail #list all failed ip addresses with ip to domain name
         % check_login.pl -s user@example.com -f ip -g fail #list all failed ip addresses with ip to domain name
END
    exit 0;
}

sub setlists {
    my ($user, $ip, $typeval) = @_;

    ++$ip_list{$user}{$ip};      #we loop by this for report
    ++$fip_list{$user}{$ip}{'count'};
    ++$fip_list{$user}{$ip}{$typeval};

    return;
}

# get the hostname for the iP address if requested
sub gethostname {
    my ($gethost) = @_;
    my $attacker = "";

    if (($gethost =~ m/all/i) 
    || (($gethost =~ /fail/i) && ((exists $fip_list{$user}{$ip}) && ($fip_list{$user}{$ip}{count})))) {
	if((gethostbyaddr(inet_aton($ip), AF_INET)) =~ /([a-z0-9_\-]{1,5})?(:\/\/)?(([a-z0-9_\-]{1,})(:([a-z0-9_\-]{1,}))?\@)?((www\.)|([a-z0-9_\-]{1,}\.)+)?([a-z0-9_\-]{3,})(\.[a-z]{2,4})(\/([a-z0-9_\-]{1,}\/)+)?([a-z0-9_\-]{1,})?(\.[a-z]{2,})?(\?)?(((\&)?[a-z0-9_\-]{1,}(\=[a-z0-9_\-]{1,})?)+)?/) {
                   $attacker="$10$11$15";
		}
    }

   return $attacker;
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
    my $fcolor = 'YELLOW';
    my $srchuser = '@';
    my $failtype = 'none';	#default failure behavior (user|ip|none)
    my $gethost = 'fail';       #default lookup behavior (all|fail|none)
    my $help, $dbug = 0;
    &GetOptions( "color=s" => \$fcolor,
                "srchuser=s" => \$srchuser,
                "fail=s" => \$failtype,  # user, ip, none
                "gethost=s" => \$gethost,   # all, fail, none
                "debug" => \$dbug,  # turn on debugging
                "help" => \$help);

    # call Help if parameters do not meet expected values or help is requested
    usage() if($help || ($failtype !~ m/^user|ip|none$/i) || ($gethost !~ m/^all|fail|none$/i));


#========================================================================
# SECTION -  PARSE audit.log files & process accordingly
#========================================================================
chdir "/opt/zimbra/log";

for (glob 'audit.log*') {

  $lines = 0;
  $audit_log = $_ eq 'audit.log' ? 1 : 0;
  #print "Opening file $_";
  open (IN, sprintf("zcat -f %s |", $_))
       or die("Can't open pipe from command 'zcat -f $filename' : $!\n");

  # part the audit logs looking for access types
  # we just doing this
  # zcat -f /opt/zimbra/log/audit.log* | grep -i invalid |egrep '(ImapS|Pop|http)'
  while (<IN>)
  {
   if (m#invalid#i)
   {
          #print $_;
      if ((m#ImapS#i) && !(m#INFO#))
      {
          my($ip,$user) = m#.*\s+\[ip=.*;oip=(.*);via=.*;\]\s*.* failed for\s+\[(.*)\].*$#i;
          $uagent = "imap";
          #print " - ip is $ip, user is $user, agent is $uagent\n";
          #print $_;
	  setlists($user, $ip, $uagent);
      }
      elsif ((m#Pop#i) && !(m#INFO#)) 
      {
         my($ip,$user) = m#oip=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3});.* failed for\s+\[(.*)\].*$#i;
         $uagent = "pop";
         #print " - ip is $ip, user is $user, agent is $uagent\n";
         #print $_;
	 setlists($user, $ip, $uagent);
      }
      elsif ((m#http#i) && (m#zclient#))
      {
          my($user,$ip,$uagent) = m#.*\s+\[name=(.*);oip=(.*);ua=(.*);\].*$#i;
          $uagent = "web";
          #print " - ip is $ip, user is $user, agent is $uagent\n";
          #print $_;
	  setlists($user, $ip, $uagent);
      }
      elsif ((m#oproto=smtp#) && (m#failed#))
      {
          my($ip,$user) = m#oip=(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3});.* failed for\s+\[(.*)\].*$#i;
          $uagent = "smtp";
          #print " - ip is $ip, user is $user, agent is $uagent\n";
          #print $_;
	  setlists($user, $ip, $uagent);
      }
   }
   elsif (m#AuthRequest#i && ($_ !~ m/zimbra/i))
   {
      my($user,$ip,$uagent) = m#.*\s+\[name=(.*);oip=(.*);ua=(.*);\].*$#i;
      ++$ip_list{$user}{$ip};
      #if ($audit_log == 1) { print $_; }
      #printf "%4d: - ip is %15s, user is %45s, agent is %s\n",$lines,$ip,$user,$uagent;
   }
   $lines++;
  } # End While (<IN>) loop
  close (IN);

}

#========================================================================
# SECTION -  PRINT / MAIN
#========================================================================
#debug
#print Dumper \%ip_list;
#print Dumper \%fip_list;


   drawline();

# Print out the arrays by username. Flag failures.
for $user (sort keys %ip_list )
{

  # Skip this user, if -s parameter is given and user is not in search string
  next if(index($user,$srchuser) == -1);

  # Proceed only  if we're only looking for users who have failed logins recorded
  next if(($failtype =~ /user|ip/i) && !(exists $fip_list{$user}));

  $total = 0;
  $totalf = 0;

   for $ip (sort {$ip_list{$user}{$b} <=> $ip_list{$user}{$a}}  keys %{$ip_list{$user}} )
   {

       #  See count of how many times
	if(($failtype !~ /ip/i)  || (($failtype =~ /ip/) && exists $fip_list{$user}{$ip})) {
             printf ("[%4d] logins from IP %15s ", $ip_list{$user}{$ip},$ip);
	}
        $total = $total+$ip_list{$user}{$ip}; # Count all for this username

	# lookup the domain if requested
	my $attacker = "[" . gethostname($gethost) . "]";

        if ((exists $fip_list{$user}{$ip}) && ($fip_list{$user}{$ip}{count})) 
        {
            print color($fcolor);
            printf "%-30s", $attacker if ($gethost !~ /none/i);

            printf " Failed [%4d] : ", $fip_list{$user}{$ip}{count};
	    for $etypes (keys %{$fip_list{$user}{$ip}}) {
   		next if $etypes =~ /count/;
                printf " using %s  [%4d] ", $etypes, $fip_list{$user}{$ip}{$etypes};
	     }
             print color('reset');
             printf ("\n");
             $totalf = $totalf+$fip_list{$user}{$ip}{count}; # Count all failed for this username
         } elsif (($gethost =~ /all/i) && !($failtype =~ /ip/i)) 
	 {
		printf "$attacker\n";
	 } elsif ($failtype !~ /ip/) {
            printf ("\n");
	 }
   }

   # Print out user information & message totals
   if ($totalf>0)  {
        my $msg = sprintf("%d failed of total %d  login attempts!!!", $totalf, $total); 
	$msgcolor = $totalf==$total ? "RED" : "YELLOW";
        printresults("WHITE", "BOLD", $user, $msgcolor, $msg);
   } elsif ($failtype !~ /ip/i) {
        my $msg = " No failed logins. Yeeee :)";
        printresults("WHITE", "BOLD", $user, "GREEN", $msg);
   }

   drawline();
}
   printf ("\n");
   print color('reset');  # make sure we clean up
