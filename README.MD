# check_login.pl

# Purpose
Report various accesses to the zimbra mail system (web,imap,pop,etc). List the ip's per user and the number of access per ip. Need permission to /opt/zimbra/audit.log as the user running this script.

# Operation
```bash
% check_login.pl
```

# Usage:
~~~~
usage: % check_login.pl 
        [--color=<color name (i.e. RED)>]
        [--srchuser=<username>]
        [--fail=<user|ip|none>]
        [--gethost=<all|fail|none>]
        [--help]
    where:
        --color|c: color to be used for FAILED login message information
        --srchuser|s: print ONLY the logins/failed logins for <username>
        --fail|f: if 'user': print ONLY users who have failed logins. If 'ip': print ONLY the failed login attempts. 'none': print all records regardless if failure
        --gethost|g: values of 'all', 'fail' or 'none'. Perform a GETHOSTBYADDR for all IPs, only on FAILED login attempts, or don't perform this action (none)
        --help|h: this message
";
example: % check_login.pl -f=user    #only the accounts with failed logins
         % check_login.pl -f ip      #only the accounts and the ip that failed
         % check_login.pl -fail=ip   # same as above
         % check_login.pl --fail ip  # same as above
         % check_login.pl -f ip -h   #list only ip's that failed for accounts resolve ip to domain name
         % check_login.pl -g fail    #list only accounts that had a failed login
         % check_login.pl -g all     #list all accounts and resolve ip to domain name
         % check_login.pl -c RED -f ip #change color and list only failed ip's     
         % check_login.pl -s user -f ip -g fail #list all failed ip addresses with ip to domain name
         % check_login.pl -s user.com -f ip -g fail #list all failed ip addresses with ip to domain name
~~~~

```bash
# Sample Report (original before recent update)
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
# CAVEATS
The failed report happens after the ip access report per user in the same list. A count of 1 for example for a failed doesn't mean they had a successful login. In other words, if you see a fail with an ip address and it has a count of 1 but the ip address has a count of 2 above. That means one time was successful and the other time was failed.

# Other Scripts

# zmcopyTrain
Copies ham/spam to /tmp to view how uses are training spam

# zmbounceMsg
Shows commands necessary to bounce messages to user that was stopped by virus dection.
Also show where the physical files are to allow admin to view the contents.

# check_rejected_spam.pl
Start of a more general purpose summary script

# check_recipients.pl
Tracking of outgoing messages based on how many they are sending.
Can we determine a hacked account by the type of outgoing? 

# check_attacks.pl
Track attacks against zimbra installations.  Can output list of ip's or ipsets for blocking.

```bash
# Sample output
	[ 200] GET /  Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36
 Attacker from 71.6.232.7                       1 failed - Score 0% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  bot
	[ 200] GET /  bot
	[ 200] GET /  bot
	[ 200] GET /  bot
 Attacker from 74.82.47.5                       4 failed - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET //a2billing/customer/templates/default/footer.tpl  python-requests/2.6.0 CPython/2.7.5 Linux/3.10.0-957.10.1.el7.x86_64
 Attacker from 77.247.109.112                   1 failed - Score 0% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko
 Attacker from 90.216.214.64                    1 failed - Score 0% 
------------------------------------------------------------------------------------------------------------
	[ 400] \x05\x01\x00 bot
	[ 400] \x04\x01\x00P\x05\xBC\xD2e\x00 bot
	[ 400] GET http://5.188.210.101/echo.php  Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36
 Attacker from 5.188.210.101                    3 failed - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  bot
 Attacker from 94.156.35.184                    1 failed - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 400] POST /Autodiscover/Autodiscover.xml  python-requests/2.18.4
 Attacker from 95.179.215.180                   1 failed - Score 0% 
```
