#!/bin/bash

#
# usage: blcheck 1.1.1.2
#        check_attacker.pl --pstatus=400 --iplist | blcheck.sh
#        cat list-of-ips | blcheck.sh
#
# Proof of Concept: what lists to try?
#
# Author: Jim Dunphy jad AT aesir.com (4/29/2019)
#

BLISTS="
    cbl.abuseat.org
    dnsbl.sorbs.net
    bl.spamcop.net
    zen.spamhaus.org
"

# register at http://www.projecthoneypot.org/httpbl_api.php 
# to obtain an API-key (free)
#
# add this to the BLISTS above -  dnsbl.httpbl.org
#HTTPbl_API_KEY="[your_api_key]"

function lookupIP {

ip=$1

if [ -z "${ip}" ];then return;fi

#assumes proper ip address
reverse=$(echo $ip | awk -F\. '{printf "%s.%s.%s.%s",$4,$3,$2,$1}')

# -- cycle through all the blacklists
for BL in ${BLISTS}
do
    # dig to lookup the name in the blacklist
    printf "%-50s" " ${reverse}.${BL}."
    if [ "$BL" == "dnsbl.httpbl.org" ];
    then
      HIT="$(dig +short -t a ${HTTPbl_API_KEY}.${reverse}.${BL}.)"
      echo ${HIT:----}
    else
      #echo dig +short -t a ${reverse}.${BL}.
      HIT="$(dig +short -t a ${reverse}.${BL}.)"
      echo ${HIT:----}
    fi
done
}

# From the comand line or from stdin
{
    [ "$#" -gt 0 ] && printf '%s\n' "$@"
    [ ! -t 0 ]     && cat
} |
while IFS= read -r; do
    lookupIP "$REPLY"
    #printf 'Got "%s"\n' "$REPLY"
done

exit;
