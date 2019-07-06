#!/bin/bash
#
# Notify us X days in advance of pending renewal for acme.sh letsencrypt renewal.
#
# Verify you have this script in your zimbra crontab entry. Should look something like this.
#
# # ZIMBRAEND -- DO NOT EDIT ANYTHING BETWEEN THIS LINE AND ZIMBRASTART
#
# 18 0 * * * "/opt/zimbra/.acme.sh"/acme.sh --cron --home "/opt/zimbra/.acme.sh" > /dev/null
# 17 0 * * * /usr/local/bin/zmcertNotice.sh > /dev/null 2>&1
#
# You need to supply your email at STEP 1. There is only 1 step :-)
#

export PATH=~/.acme.sh:/bin:/usr/bin:/usr/sbin:/usr/local:$PATH

#
# Quick/Dirty script to notify us via email the day
#  prior to a letsencrypt renew cycle by acme.sh
#
#
email="XXX@XXXX.com"	# %%% STEP 1: CHANGE THIS
sendmail="/opt/zimbra/common/sbin/sendmail"

domainCert=$(acme.sh --list | sed 1d | head -1 | awk '{printf "%s",$3}')
subject="$domainCert Certificate renewal in 1 day(s)"
message="Hello,
this is a reminder that $domainCert letsencrypt certificate
will try to obtain and install new zimbra certificate in 1 day(s)."

#-------------------------------
# What acme.sh thinks when it could renew

renewalDate=$(acme.sh --list | sed 1d | head -1 | awk '{printf "%s %s %s %s %s %s",$10,$11,$12,$13,$14,$15}')

# first renewal date
cmd="date +%s -d \"$renewalDate\""
r_time=$(eval $cmd)

#-------------------------------
# Subtract 1 day and see if could?

# we want to know 2 days in advance
currentDate=$(date -u)	# now

cmd="date +%s -d \"$currentDate+2 days\""
r_time_in_future=$(eval $cmd)

#-------------------------------

if [ $r_time_in_future -gt $r_time ]; then
  echo "will renew in 1 day"

echo "Subject: $subject

$message" | "$sendmail" "$email"
fi
