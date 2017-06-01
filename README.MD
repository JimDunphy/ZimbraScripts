# check_login.pl

# Purpose
Report various accesses to the zimbra mail system (web,imap,pop,etc). List the ip's per user and the number of access per ip. Need permission to /opt/zimbra/audit.log as the user running this script.

# Operation
```bash
% check_login.pl

# Sample Report
annaSmith@example.com
 [   2] - 24.118.12.16

flo@example.net
 [   3] - 24.118.12.16

annaSmith@example.net
 [  15] - 24.118.12.16

bldd1@example.com
 [   1] - 220.180.172.173
 [   1] - 58.248.164.150
 [   1] - 41.210.223.10
 [   1] - 222.242.229.42
 [   1] - 222.191.233.238
 [   1] - 80.13.84.146
 [   1] - 213.138.74.85
 [   1] - 220.170.196.198
 [   1] - 117.158.101.182
 [   1] - 59.61.79.82
 [   1] - 218.64.77.6
 [   1] - 59.61.79.82  failed imap 
 [   1] - 218.64.77.6  failed imap 
 [   1] - 213.138.74.85  failed imap 
 [   1] - 117.158.101.182  failed imap 
 [   1] - 41.210.223.10  failed imap 
 [   1] - 220.170.196.198  failed imap 
 [   1] - 222.191.233.238  failed imap 
 [   1] - 80.13.84.146  failed imap 
 [   1] - 222.242.229.42  failed imap 
 [   1] - 220.180.172.173  failed imap 
 [   1] - 58.248.164.150  failed imap 

```
# CAVEOTS
The failed report happens after the successful report per user in the same list. A count of 1 for example for a failed doesn't mean they had a successful login. In other words, if you see a fail with an ip address and it has a count of 1 but the ip address has a count of 2 above. That means one time was successful and the other time was failed.
