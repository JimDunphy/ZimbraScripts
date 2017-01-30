#!/usr/bin/perl

use Data::Dumper qw(Dumper);

%ip_list = ();  #ip list
%fip_list = ();	#failed ip list
$audit_log = 0;	#todays logging

chdir "/opt/zimbra/log";

for (glob 'audit.log*') {

  # audit.log is always todays stuff
  #print "Opening file $_";
  if ($_ eq 'audit.log')
  {
     $audit_log = 1;
     open (IN, sprintf("cat %s |", $_))
       or die("Can't open pipe from command 'zcat $filename' : $!\n");
  }
  else
  {
     $audit_log = 0;
     open (IN, sprintf("zcat %s |", $_))
       or die("Can't open pipe from command 'zcat $filename' : $!\n");
  } 

  while (<IN>) 
  {
	if (m#invalid password#i)
	{ 
		#print $_;
		if (m#ImapServer#i) {
		my($ip,$user) = m#.*\s+\[ip=.*;oip=(.*);via=.*;\]\s*.* failed for\s+\[(.*)\].*$#i;
		$uagent = "imap";
		#print " - ip is $ip, user is $user, agent is $uagent\n";
		#print $_;

		++$ip_list{$user}{$ip};		#we loop by this for report
		++$fip_list{$user}{$ip}{'count'};
		++$fip_list{$user}{$ip}{'imap'};
		}
		elsif (m#Pop3Server#i) 
		{
		my($ip,$user) = m#.*\s+\[ip=.*;oip=(.*);\]\s*.* failed for\s+\[(.*)\].*$#i;
		$uagent = "pop";
		#print " - ip is $ip, user is $user, agent is $uagent\n";
		#print $_;
		++$ip_list{$user}{$ip};		#we loop by this for report
		++$fip_list{$user}{$ip}{'count'};
		++$fip_list{$user}{$ip}{'pop'};
		}
		elsif (m#http#i) 
		{
		my($user,$ip,$uagent) = m#.*\s+\[name=(.*);oip=(.*);ua=(.*);\].*$#i;
		$uagent = "web";
		#print " - ip is $ip, user is $user, agent is $uagent\n";
		#print $_;
		++$ip_list{$user}{$ip};		#we loop by this for report
		++$fip_list{$user}{$ip}{'count'};
		++$fip_list{$user}{$ip}{'web'};
		}
	}
	elsif (m#AuthRequest#i && ($_ !~ m/zimbra/i)) 
	{
		my($user,$ip,$uagent) = m#.*\s+\[name=(.*);oip=(.*);ua=(.*);\].*$#i;
		++$ip_list{$user}{$ip};
		#$ip_list{$user}{'Agent'} = $uagent;
		if ($audit_log == 1) { print $_; }
		#print " - ip is $ip, user is $user, agent is $uagent\n";
	}
  }
  close (IN);

}


#debug
#print Dumper \%ip_list;
#print Dumper \%fip_list;

for $user (sort {$ip_list{$b} <=> $ip_list{$a}}  keys %ip_list )
{

  print "\n",$user,"\n";


	for $ip (sort {$ip_list{$user}{$b} <=> $ip_list{$user}{$a}}  keys %{$ip_list{$user}} )
	{
		#  See cont of how many times
		printf (" [%4d] - %s\n", $ip_list{$user}{$ip},$ip);
		#printf ("%s\n",$ip);
	}

	# failed
	for $ip (sort {$fip_list{$user}{$b} <=> $fip_list{$user}{$a}}  keys %{$fip_list{$user}} )
	{
		#  See cont of how many times
		printf (" [%4d] - %s ", $fip_list{$user}{$ip}{count},$ip);
		printf " failed web " if exists $fip_list{$user}{$ip}{'web'};
		printf " failed imap " if exists $fip_list{$user}{$ip}{'imap'};
		printf " failed pop " if exists $fip_list{$user}{$ip}{'pop'};
		printf ("\n");
#%%% we can have different user's in fip_list that ip_list doesn't have.
		#printf ("%s\n",$ip);
	}
}
