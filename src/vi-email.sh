#!/bin/sh

# Description: 
#    edit a list of files matching a pattern
# usage: 
#    vi-email.sh example.com
# expected results:
#    Any file that contained example.com would be in the edit list
#    ^n for vi users to cycle through list

email=$1

vi `grep $email /tmp/zmtrain*/* | awk -F: '{print $1}' | sort -u`
ls -l `grep $email /tmp/zmtrain*/* | awk -F: '{print $1}' | sort -u`
