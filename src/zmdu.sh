#!/bin/bash
# 
# Printout email disk usage for all accounts in human readable form
#
# usage: zmdu.sh
#
# Ouptut: user size(human readable)
#     0 ... admin@example.com
#   15K ... wiki@example.com
#   75M ... sam@example.com
#   17K ... ham.lub2tukfun@example.com
#    3G ... jim@example.com
#
# Caveat: zmprov is slow... So slow you won't believe it. :-)
#
# Required: NEEDS to RUN as THE ZIMBRA USER
#
# Author: Jim Dunphy 
#
# Sort by highest users 
# % zmdu.sh | sort -rh  
# 
# has no output until completed so this might work better or use tee
# % zmdu.sh > zmdu.out
# % sort -rh zmdu.out
#    3G ... jim@example.com
#    3G ... betsy@example.com
#  696M ... anna@example.com
#   72M ... sam@example.com
#   67M ... helen@example.com
#   12M ... noc@example.com
#  460K ... spam.trivkbr1q@example.com
#   27K ... wiki@mail.example.com
#   17K ... ham.lub2tukfun@example.com
#   15K ... wiki@example.com
#    54 ... virus-quarantine.t98l1ltk1a@example.com
#     0 ... admin@example.com
# 

for account in `zmprov -l gaa`
do
  result=$(zmprov gmi "$account" | awk '{/mailboxId/} { print $2 }' | tail -1)
  size=$(echo $result | awk '{ suffix=" KMGT"; for(i=1; $1>1024 && i < length(suffix); i++) $1/=1024; print int($1) substr(suffix, i, 1), $3; }')
  printf "%6s ... %s\n" $size  $account
done

exit 0
