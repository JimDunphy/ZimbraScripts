#!/bin/bash
# 
# Printout email disk usage for all accounts in human readable form
#
# usage: zmdu.sh
#
# Required: NEEDS to RUN as THE ZIMBRA USER
#
# Author: Jim Dunphy, assist: Klug from Zimbra forums.
#
# Sorted by highest users 
# 
# su - zimbra
# % zmdu.sh 
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

zmprov gqu $(zmhostname) | awk '{ $2="";suffix=" KMGT"; for(i=1; $3>1024 && i < length(suffix); i++) $3/=1024; printf "%6s%c ... %s\n", int($3),substr(suffix, i, 1), $1; }' | sort -rh

exit 0
