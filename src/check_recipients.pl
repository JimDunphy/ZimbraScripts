#!/usr/bin/perl

# test of concept...
#  Can we determine a hacked account by the type of outgoing
# Note: /var/log/mailog* is generally owned by root only

use Data::Dumper qw(Dumper);

%sender_list = ();  #ip list
%fsender_list = ();	#failed ip list
$audit_log = 0;	#todays logging

chdir "/var/log";

for (glob 'maillog*') {

open (IN, sprintf("zcat -f %s |", $_))
   or die("Can't open pipe from command 'cat $filename' : $!\n");

my($PFID) = 0;
  while (<IN>) 
  {
    if (m#postfix/smtpd#i)
    { 
       if (m#client=#) 
       {
          ($PFID) = m#]:\s*(.*):#;
          #print "id is $PFID\n";
       }
       elsif (m#<>:#)
       {
           my($recipient) = m#to=<(.*)>\s*proto#;
	  ++$fsender_list{$recipient} if ($recipient ne "");
       }
       elsif (m#filter|127.0.0.1# && $PFID)
       {
          my($sender,$recipient) = m#from=<(.*)>\s*to=<(.*)>\s*proto#;
          #print " sender is $sender, recipient is $recipient\n";
	  #print $_;

	  ++$sender_list{$PFID}{$sender} if ($sender ne "");		
	  ++$sender_list{$PFID}{'bounce'} if ($sender eq "");
	  #$sender_list{$PFID}{'recipient'} = $recipient . ' ' . $sender_list{$PFID}{'recipient'} if ($recipient ne "");
        }
    }
  }
  close (IN);
}



#debug
#print Dumper \%sender_list;
#print Dumper \%fsender_list;

for $PFID (sort keys %sender_list )
{

#  print "\n",$sender_list{$PFID}{sender},"\n";


	for $user (keys %{$sender_list{$PFID}}) 
	{
           if (exists $sender_list{$PFID}{$user}) 
           {
		#  See cont of how many times
		if ($sender_list{$PFID}{$user} > 20) 
                {
		   printf ("%s Total [%4d] - %15s ",$PFID, $sender_list{$PFID}{$user},$user);
		   printf " Bounces [%4d]", $sender_list{$PFID}{'bounce'} if $sender_list{$PFID}{'bounce'};
		   #print $_, "\n", for split ' ', $sender_list{$PFID}{'recipient'};

		printf ("\n");
		}
	    }

         }
}

# Abnormal bounces for users
for $user (sort keys %fsender_list )
{
     if (exists $fsender_list{$user}) 
     {
	#  See cont of how many times
	if ($fsender_list{$user} > 10) 
        {
            printf ("Total Bounces [%4d] for %s\n", $fsender_list{$user},$user);
        }
      }
}
