#!/usr/bin/perl

#
# Zimbra Assumptions:
# Amavis at level 3 logging to see spam_scan lines in /var/log/zimbra.log to parse:
#   % zmprov ms `zmhostname` zimbraAmavisLogLevel 3
#   % zmantispamctl restart
#
# %%% not completed
# Bugs: amavis is threaded and the logs contain multiple row records.
#      This script needs the parser to hold the data before counting.

use Data::Dumper qw(Dumper);
use Getopt::Long;

%Email_list = ();  #ip list
%SA_Rules_list = ();	#failed ip list
$audit_log = 0;	#todays logging

sub usage {

print <<"END";
usage: % check_spam.pl 
      [--user=<username>]
      [--ham|h ]
      [--spam|s ]
      [--discard|d ]
      [--rules|r ]
      [--option|o ]
    requires one of
       --ham | --spam | --discard
    where
       --ham will display only ham
       --spam will display only spam
       --discard will display not delivered email due to scoring
       --rules DO NOT display SA rules that fired
       --user will display only email destined for that user
END
  exit 0;
}

#defaults
my $srchuser = '@';
my $ham = 0;
my $spam = 0;
my $discard = 0;
my $rules = 0;
my $help = 0;
my $dcount=0;
my $scount=0;
my $hcount=0;
my $tcount=0;

&GetOptions( "user=s" => \$srchuser,
              "ham" => \$ham,     # display ham
              "discard" => \$discard,  # display discarded not delivered email
              "rules" => \$rules, # display SA rules
              "spam" => \$spam,   # display spam
              "options" => \$help);

print "user is $srchuser rules[$rules] ham[$ham] spam[$spam] discard[$discard]\n";
my $nodisplayoptions=$ham + $spam + $discard;
usage() if($help || !$nodisplayoptions);

chdir "/var/log";

#for (glob 'zimbra.log*') {
for (glob 'zimbra.log') {

  # audit.log is always todays stuff
  #print "***** Opening file $_","\n";
  if ($_ eq 'zimbra.log')
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

my $score=0;
my $tests="";
my $flag=0;

  while (<IN>) 
  {
	# Available when in level 3 logging
	if (m#spam_scan#)
	{ 
		#print $_;
		($score,$tests) = m#\s+score=(-?\d+\.?\d*).*tests=\[(.*)\]\s*#i;
		#print " - score is $score, tests is $tests \n";

		# %%% spam_scan can be consequtive given this is multi-threaded writes from the amavisd's.
                #  resulting in lost records.
		#if ($flag) {print " - score is $score, tests is $tests \n";}
		$flag=1;

	}
	# Always available
        # Discarded spam
	elsif (m#DiscardedInbound# && ($flag == 1) && (m#Blocked#))
	{
		#print " - score is $score, tests is $tests \n";
		my($from,$to,$hits,$size) = m#[^<]+<([^>]+)>[^<]+<([^>]+)\>.*Hits:\s*(\d+\.?\d*),\s*size:\s+(.*)$#i;

                #by user
                next if(index($to,$srchuser) == -1);
		next if (!$discard);

		# Sanity check for working on same record
		if ($hits != $score) { next; }

		printf ("Score [%6s] To: %s From: %s\n", $score, $to, $from);
		printf ("      %s\n\n", $tests) if (!$rules);

		# reset, and look for next spam_scan line
		$score=0;
		$tests="";
		$flag=0;
		$dcount++;
	}
        # Ham
	elsif (m#spam-tag# && ($flag == 1) && (m#No#))
	{
		#print " - score is $score, tests is $tests \n";
		my($from,$to,$hits) = m#spam-tag,\s+\<+([^>]+)\>+\s+-\>\s+\<+([^>]+)\>+,\s+No,\s+score=(-?\d+\.?\d*)\s+.*$#i;

                #by user
                next if(index($to,$srchuser) == -1);
		next if (!$ham);

		# Sanity check for working on same record
		if ($hits != $score) { next; }

		#print $_;

		printf ("Score [%6s] To: %s From: %s\n", $score, $to, $from);
		printf ("      %s\n\n", $tests) if (!$rules);

		# reset, and look for next spam_scan line
		$score=0;
		$tests="";
		$flag=0;
		$hcount++;
	}
	# Spam but not discarded
	elsif (m#spam-tag# && ($flag == 1) && (m#Yes#))
	{
		#print " - score is $score, tests is $tests \n";
		my($from,$to,$hits) = m#spam-tag,\s+\<+([^>]+)\>+\s+-\>\s+\<+([^>]+)\>+,\s+Yes,\s+score=(-?\d+\.?\d*)\s+.*$#i;

                #by user
                next if(index($to,$srchuser) == -1);
		next if (!$spam);

		# Sanity check for working on same record
		if ($hits != $score) { next; }

		#print $_;

		printf ("Score [%6s] To: %s From: %s\n", $score, $to, $from);
		printf ("      %s\n\n", $tests) if (!$rules);

		# reset, and look for next spam_scan line
		$score=0;
		$tests="";
		$flag=0;
		$scount++;
	}
  }
  close (IN);

}

$tcount += $dcount if ($discard);
$tcount += $scount if ($spam);
$tcount += $hcount if ($ham);

printf ("\nTotal counts: $tcount");
printf (" Discarded Email: $dcount") if ($discard);
printf (" Spam Email: $scount") if ($spam);
printf (" Ham Email: $hcount") if ($ham);
printf ("\n");
