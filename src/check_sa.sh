#!/bin/bash 

#
# usage: check_sa.sh somefile.txt
# 
# output: somefile.txt.out
#
# Documentation:
#
# https://wiki.apache.org/spamassassin/DebugChannels for -D 'dns,check', etc
#
#spamassassin -D --lint --dbpath /opt/zimbra/data/amavisd/.spamassassin 2>&1 < 16b9792b67f-10 
#spamassassin -D --lint --dbpath /opt/zimbra/data/amavisd/.spamassassin < 16b9792b67f-10 
#spamassassin -D  --dbpath /opt/zimbra/data/amavisd/.spamassassin 2>&1 < 16b9792b67f-10 
#spamassassin -D -L --dbpath /opt/zimbra/data/amavisd/.spamassassin 2>&1 < 16b9792b67f-10 
#spamassassin -D -L --dbpath /opt/zimbra/data/amavisd/.spamassassin < 16b9792b67f-10 >/dev/null
#spamassassin -Ddns -L --dbpath /opt/zimbra/data/amavisd/.spamassassin < 16b9792b67f-10 >/dev/null
#spamassassin -D dns,bayes,check < 16b9792b67f-10 >/dev/null
#spamassassin -D dns,bayes,check < 16b9792b67f-10 >/dev/null

. /opt/zimbra/.bashrc

#export PERL5LIB=/opt/zimbra/common/lib/perl5/x86_64-linux-thread-multi:/opt/zimbra/common/lib/perl5
#export PERLLIB=/opt/zimbra/common/lib/perl5/x86_64-linux-thread-multi:/opt/zimbra/common/lib/perl5

usage() {
  echo "

    usage: 
     $ check_sa.sh file.txt
     $ check_sa.sh -n file.txt
     $ check_sa.sh -flags DNS,check file.txt

    output: file.txt.out

    Options to run spamassassin in Debug Mode

    --flags DNS,bayes,check
    --net (do network tests - remove -L option)
    --help

  see: https://wiki.apache.org/spamassassin/DebugChannels for -D 'dns,check'

  "
}


# default is local tests only
nflags="-L"

#
args=$(getopt -l "flags:,help,net" -o "f:hn" -- "$@")

eval set -- "$args"

while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                   ;;
                -f|--flags)
                        flags="$2"
                        shift
                        ;;
                -n|--net)
                        nflags=""
                        ;;
                -h|--help)
                        usage
                        exit 0
                        ;;
        esac

        shift
done

#echo "flags: $flags"
#echo "remaining args: $*"
file="$*"

if [ ! -f $file ] || [ -z $file ]; then
   usage
   echo "****** ERROR: missing filename ******";
   exit 1;
fi

#echo "spamassassin -D $flags $nflags" ' < ' "$file"  ' > ' "$file".out
spamassassin -D $flags $nflags < "$file" > /dev/null 2> "$file".out

exit 0
