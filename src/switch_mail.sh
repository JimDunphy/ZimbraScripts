#!/bin/bash 

#
# Author: Jim Dunphy <jad aesir.com>
# License (ISC): It's yours. Enjoy
# Date: 10/28/2022
#
# usage: switch_mail.sh --[stop|start] [zimbra|carbonio]

#
# 11/1/2022 - jad @

#
# Purpose: 
#    script to freeze zimbra/cabonio installed running on a host
#    Allows one to stop them from running and easily switch between them
#    or run non of them until you need to test/verify them.
#

usage() {
  echo "
    usage: 

     freeze - moves cron aside and stops any systemctl services
     unfreeze - moves everything back

     $ switch_mail.sh --stop zimbra
     $ switch_mail.sh --start carbonio
     $ switch_mail.sh --stop  zimbra
     $ switch_mail.sh --start carbonio
     $ switch_mail.sh --flip 

     Can only have one active at a time
  "
}

doCarbonio() {
    cmd="$1"	# stop|start|disable|enable

systemctl $cmd carbonio-docs-connector
systemctl $cmd carbonio-docs-connector-sidecar.service                          
systemctl $cmd carbonio-docs-connector.service                                 
systemctl $cmd carbonio-files-db-sidecar.service                              
systemctl $cmd  carbonio-files-sidecar.service                                
systemctl $cmd  carbonio-files.service                                       
systemctl $cmd  carbonio-mailbox-sidecar.service                            
systemctl $cmd  carbonio-mta-sidecar.service                               
systemctl $cmd  carbonio-proxy-sidecar.service                            
systemctl $cmd  carbonio-storages-sidecar.service                        
systemctl $cmd  carbonio-storages.service                               
systemctl $cmd  carbonio-user-management-sidecar.service               
systemctl $cmd  carbonio-user-management.service                      
systemctl $cmd  carbonio-docs-editor.service
systemctl $cmd  service-discover.service                      

}


freeze=0 	#default do nothing

args=$(getopt -l "help,stop,start" -o "sg" -- "$@")
eval set -- "$args"

while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
		    shift
                    break
                   ;;
                -s|--stop)
                        freeze=1
                        ;;
                -g|--start)
                        freeze=0
                        ;;
                -h|--help)
                        usage
                        exit 0
                        ;;
        esac

        shift
done

mail="$*"

#echo "freeze: $freeze"
#echo "remaining args: $*"
#echo "mail is [$mail]"

case "$mail" in
     'carbonio')  
         echo "doing carbonio actions"
         if [ $freeze == 1 ]; then
              echo "****** zmcontrol stop"
              su - zextras -c "zmcontrol stop"
              mv /var/spool/cron/zextras /var/spool/cron/zextras-
              doCarbonio stop
              doCarbonio disable
              chkconfig --level 2345 carbonio off
         else
              echo "****** zmcontrol start"
              su - zextras -c "zmcontrol start"
              mv /var/spool/cron/zextras- /var/spool/cron/zextras
              doCarbonio enable
              doCarbonio start
              chkconfig --level 2345 carbonio on
         fi
         ;;
     'zimbra')  
         echo "doing zimbra actions"
         if [ $freeze == 1 ]; then
              echo "****** zmcontrol stop"
              su - zimbra -c "zmcontrol stop"
              mv /var/spool/cron/zimbra /var/spool/cron/zimbra-
              chkconfig --level 2345 zimbra off
         else
              echo "****** zmcontrol start"
              su - zimbra -c "zmcontrol start"
              mv /var/spool/cron/zimbra- /var/spool/cron/zimbra
              chkconfig --level 2345 zimbra on
         fi
         ;;
     *) 
         usage
         exit 0
         ;;
esac
