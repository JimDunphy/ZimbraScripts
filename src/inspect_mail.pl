#!/usr/bin/perl

#
# usage: cat file | inspect_mail.pl
#
#Return-Path: rosenjason789@gmail.com
#X-Spam-Status: No, score=2.968 required=4.8 tests=[BAYES_80=2,
#	DKIM_SIGNED=0.1, DKIM_VALID=-0.1, DKIM_VALID_AU=-0.1,
#	FREEMAIL_ENVFROM_END_DIGIT=0.25, FREEMAIL_FROM=0.001,
#	HTML_MESSAGE=0.001, J_DNSBL_MILTER_META=0.3, J_DOCTYPE_MISSING=0.5,
#	J_RCVD_IN_HOSTKARMA_YEL=0.003, RCVD_IN_DNSWL_NONE=-0.0001,
#	RCVD_IN_MSPIKE_H3=0.001, RCVD_IN_MSPIKE_WL=0.001, SPF_HELO_NONE=0.001,
#	T_GB_FREEMAIL_DISPTO=0.01] autolearn=no autolearn_force=no
#From: "Jason Rosen" <rosenjason789@gmail.com>
#To: <user@example.com>
#Subject: Health and Safety Professionals Email List
#
# 6/14/2019 - JAD

use strict;
use warnings;

my $SPAM = "";
my $flag = 0;

while (<STDIN>) {

 my ($line) = $_;
 #  chomp;
 #  my ($line) = split;

#print $line;
   print $line if ($line =~ /Return-Path:/);
   print $line if ($line =~ /^To:/);
   print $line if ($line =~ /^Subject:/);
   print $line if ($line =~ /^From:/);
   $flag = 1 if ($line =~ /^X-Spam-Status:/);
   if ($flag)
   {
      $SPAM = $SPAM . $line;
   }
   if ($line =~ /autolearn_force/)
   {
      print $SPAM if ($line =~ /autolearn_force/);
      $SPAM = "";
      $flag = 0;
   }

}

