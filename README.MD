# Some examples of scripts in src

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

# build_zimbra.sh
Automated script to build Zimbra FOSS for version 8.8.15, 9.0.0, and 10.0.0

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
Track attacks against zimbra installations.  Can output list of ip's or ipsets for blocking.  Searches all /opt/zimbra/log/nginx.access\* logs.
It does this but orders the output by counts and pretty prints the output.  Documented in this thread. https://forums.zimbra.org/viewtopic.php?f=15&t=66092

```bash
% zcat -f /opt/zimbra/log/nginx.ac* |grep Autodiscover 
95.179.215.180:36914 - - [29/Apr/2019:06:04:23 -0700]  "POST /Autodiscover/Autodiscover.xml HTTP/1.1" 400 567 "-" "python-requests/2.18.4" "X.X.X.X:8080"
159.69.81.117:46880 - - [28/Apr/2019:05:19:00 -0700]  "POST /Autodiscover/Autodiscover.xml HTTP/1.1" 400 567 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, lik
e Gecko) Chrome/24.0.1309.0 Safari/537.17" "X.X.X.X:8080"
```
It attempts to filter out local users. The first step is to customize this for your zimbra installation the first time you run it.
Search for STEP 1 in the code.  By default, it returns attackers which are everyone else but the local users.  Local users can also be included by the --usertype=all option or just the local users by --usertype=local

# Sample outputs
```bash
% check_attacks.pl

------------------------------------------------------------------------------------------------------------
	[ 400] \x03\x00\x00*%\xE0\x00\x00\x00\x00\x00Cookie: mstshash=Test bot
	[ 400] \x03\x00\x00*%\xE0\x00\x00\x00\x00\x00Cookie: mstshash=Test bot
 Attacker from  185.153.198.201                 2 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 (Windows NT 5.1; rv:9.0.1) Gecko/20100101 Firefox/9.0.1
	[ 404] GET /HNAP1/  Mozilla/5.0 (Windows NT 5.1; rv:9.0.1) Gecko/20100101 Firefox/9.0.1
 Attacker from  185.190.149.69                  2 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 400] \x03\x00\x00/*\xE0\x00\x00\x00\x00\x00Cookie: mstshash=Administr bot
 Attacker from  185.209.0.12                    1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)
 Attacker from  185.222.209.87                  1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /.env  Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Safari/537.36
 Attacker from  185.234.218.18                  1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 400] \x03\x00\x00*%\xE0\x00\x00\x00\x00\x00Cookie: mstshash=Test bot
	[ 400] \x03\x00\x00*%\xE0\x00\x00\x00\x00\x00Cookie: mstshash=Test bot
 Attacker from  193.188.22.127                  2 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 zgrab/0.x
 Attacker from  198.108.67.16                   1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 400] POST /Autodiscover/Autodiscover.xml  python-requests/2.18.4
 Attacker from 95.179.215.180                   1 Requests - Score 25% 
```
Generate list of ip's.
```bash
% check_attacks.pl --IPlist | head -5
103.237.145.12
106.12.89.13
107.170.204.68
107.170.240.102
107.170.251.213
```
Generate list of ip's that had a status code of 400
```bash
% check_attacks.pl --IPlist --pstatus=400 | head -5
138.246.253.5
164.52.24.162
185.153.198.201
185.209.0.12
193.188.22.127
209.250.252.220
45.227.255.99
46.161.27.112
5.188.210.101
51.38.12.13
54.187.17.116
59.36.132.222
61.219.11.153
66.240.205.34
```
Generate list of ip's in ipset format. WARNING. There could be false positives unless you have tuned this program to your users.
```bash
% check_attacks.pl --IPlist --ipset --pstatus=400 |head -5
ipset add blacklist24hr 138.246.253.5 -exists
ipset add blacklist24hr 164.52.24.162 -exists
ipset add blacklist24hr 185.153.198.201 -exists
ipset add blacklist24hr 185.209.0.12 -exists
ipset add blacklist24hr 193.188.22.127 -exists
```
Search by ip addresses
```bash
% check_attacks.pl --srcip='103.237.145.12|106.12.89.13|107.170.204.68'
	[ 404] GET /admin//config.php  curl/7.29.0
 Attacker from 103.237.145.12                   1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 zgrab/0.x
 Attacker from 106.12.89.13                     1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 zgrab/0.x
 Attacker from 107.170.204.68                   1 Requests - Score 25% 
```
Search by ip range to see how many in block are attacking
```bash
% check_attacks.pl --src 93.119.227
	[ 200] GET /  Wget/1.13.4 (linux-gnu)
 Attacker from  93.119.227.19                   1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_1 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.0 Mobile/14E304 Safari/602.1
 Attacker from  93.119.227.34                   1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:58.0) Gecko/20100101 Firefox/58.0
 Attacker from  93.119.227.91                   1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------

```
Show status
```bash
% check_attacks.pl --statuscnt
Codes 200 Total: 22680
Codes 206 Total: 1
Codes 301 Total: 16
Codes 302 Total: 17
Codes 304 Total: 9
Codes 400 Total: 23
Codes 403 Total: 5
Codes 404 Total: 8
Codes 499 Total: 156
Codes 500 Total: 12
Codes 503 Total: 4
```
Print by code - all 500-509 records.  Note: may need to specify --userType=all as it defaults to attackers only
```bash
./check_attacks.pl --pstatus=206 --userType=all
	[ 206] GET /zimbra/public/sounds/im/alert.wav  Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:66.0) Gecko/20100101 Firefox/66.0
 Zimbra User from 124.18.10.247                    14528 Requests - Score 0% 
------------------------------------------------------------------------------------------------------------
```
List the ip's that your local users access the server from.
```bash
% check_attacks.pl --iplist --localuser | wc -l
55
% check_attacks.pl --iplist | wc -l
88
```
Show attackers and then swap out the user agent for time of the attack
```bash
% check_attacks.pl --srcip '95.179.215.180|18.18.248.17|112.118.155.15|159.69.81.117|212.51.217.211|112.118.155.15' 
	[ 400] POST /Autodiscover/Autodiscover.xml  python-requests/2.21.0
 Attacker from  112.118.155.15                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  python-requests/2.21.0
	[ 400] POST /Autodiscover/Autodiscover.xml  Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.17 (KHTML, like Gecko) Chrome/24.0.1309.0 Safari/537.17
 Attacker from  159.69.81.117                   2 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 400] POST /Autodiscover/Autodiscover.xml  python-requests/2.21.0
	[ 400] GET /res/I18nMsg,AjxMsg,ZMsg,ZmMsg,AjxKeys,ZmKeys,ZdMsg,Ajx%20TemplateMsg.js.zgz?v=091214175450&skin=../../../../../../../../../opt/zimbra/conf/localconfig.xml%00  python-requests/2.21.0
 Attacker from  18.18.248.17                    2 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 400] POST /Autodiscover/Autodiscover.xml  python-requests/2.18.4
 Attacker from  95.179.215.180                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
```
Now swap out user agent field for date field To see when attacks happened.

```bash
% check_attacks.pl --srcip '95.179.215.180|18.18.248.17|112.118.155.15|159.69.81.117|212.51.217.211|112.118.155.15' --display=date
	[ 400] POST /Autodiscover/Autodiscover.xml  29/Apr/2019:16:39:04
 Attacker from  112.118.155.15                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  28/Apr/2019:05:19:00
	[ 400] POST /Autodiscover/Autodiscover.xml  28/Apr/2019:05:19:00
 Attacker from  159.69.81.117                   2 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 400] POST /Autodiscover/Autodiscover.xml  29/Apr/2019:08:08:20
	[ 400] GET /res/I18nMsg,AjxMsg,ZMsg,ZmMsg,AjxKeys,ZmKeys,ZdMsg,Ajx%20TemplateMsg.js.zgz?v=091214175450&skin=../../../../../../../../../opt/zimbra/conf/localconfig.xml%00  29/Apr/2019:08:08:22
 Attacker from  18.18.248.17                    2 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 400] POST /Autodiscover/Autodiscover.xml  29/Apr/2019:06:04:23
 Attacker from  95.179.215.180                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
```
Search is different in that it locates a match and then prints all requests for that ip. It searches the requests, user agent, date, and referrer all at the same time. You may need to use the --display to confirm those matches.  For example, to search by date and if there was a POST, the following search would provide all requests for an ip address if any of those searches were previously found.
```bash
% check_attacks.pl --display=date --search '30/Apr|Post'
	[ 400] POST /autodiscover  28/Apr/2019:10:23:12
 Attacker from  47.75.173.76                    1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  30/Apr/2019:22:48:54
 Attacker from  54.37.16.241                    1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /admin//config.php  02/May/2019:07:00:52
	[ 404] GET /admin//config.php  27/Apr/2019:14:13:19
	[ 404] GET /admin//config.php  30/Apr/2019:04:47:15
	[ 404] GET /admin//config.php  01/May/2019:05:29:00
 Attacker from  138.185.144.75                  4 Requests - Score 100% 
```
Running the same search without the --display gives the same results but uagent is displayed now.
```bash
% check_attacks.pl --search '30/Apr|Post'
	[ 400] POST /autodiscover  Mozilla/5.0 (Linux; U; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.2.149.27 Safari/525.13
 Attacker from  47.75.173.76                    1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 200] GET /  Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0)
 Attacker from  54.37.16.241                    1 Requests - Score 25% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
 Attacker from  138.185.144.75                  4 Requests - Score 100% 

% check_attacks.pl --search '\.jsp|\.php'
	[ 404] GET /nx8j78af1b.jsp  Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36
 Attacker from  128.14.209.154                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /nx8j78af1b.jsp  Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36
 Attacker from  128.14.209.226                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
	[ 404] GET /admin//config.php  curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5
 Attacker from  138.185.144.75                  4 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /admin/config.php  curl/7.29.0
 Attacker from  203.147.24.220                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 404] GET /admin//config.php  curl/7.19.7 (x86_64-koji-linux-gnu) libcurl/7.19.7 NSS/3.15.1 zlib/1.2.3 libidn/1.18 libssh2/1.4.2
 Attacker from  221.212.99.106                  1 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
	[ 400] \x05\x01\x00 bot
	[ 400] \x04\x01\x00P\x05\xBC\xD2e\x00 bot
	[ 400] GET http://5.188.210.101/echo.php  Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36
 Attacker from  5.188.210.101                   3 Requests - Score 100% 
------------------------------------------------------------------------------------------------------------
```
Examples and Help
```bash
usage: % check_attacker.pl 
        [--fcolor=<color name (i.e. RED)>]
        [--srcip=<ip address>]
        [--localUser ]
        [--IPlist ]
	[--statuscnt]
	[--display="date|upstream|bytes|port|referrer]
	[--usertype=<attacker|local|all>
	[--pstatus=<regex of status codes>
        [--help]
        [--version]
    where:
        --srcip|sr: print only records matching ip addresses
	--statuscnt: prints out the count for each status return code found
        --help|h: this message
examples:  (-- or - or first few characters of option so not ambigous)
         % check_attacker.pl -srcip 10.10.10.1      #only this ip address
         % check_attacker.pl -srcip  '10.10.10.1|20.20.20.2'      #only these ip addresses
         % check_attacker.pl -statuscnt  #print status codes
         % check_attacker.pl --statuscnt  #print status codes  #same
         % check_attacker.pl --localUser #include local users accounts
         % check_attacker.pl --IPlist   # print list of ips
         % check_attacker.pl --IPlist --ipset  # print list of ips in ipset format
         % check_attacker.pl --IPlist -pstatus='40.' --ipset  # print list of ips in ipset format with status code 400..409
         % check_attacker.pl --localUser --IPlist   # print list of local ips used by local users
         % check_attacker.pl --IPlist --ipset  | sh # install ip's into ipset 
         % check_attacker.pl --initIPset  # show how to create ipset 
         % check_attacker.pl -fc RED  #change color 
         % check_attacker.pl --usertype=local  # print out strings of only local users
         % check_attacker.pl --pstatus='4..'  # print out only those requests with a code of 4XX (ie 403, 404, 499)
         % check_attacker.pl --usertype=all --pstatus='403|500'  # print out only those requests with a code of 403 or 500 for all types (local & attacker)
         % check_attacker.pl --display=date      # default is to display the user agent
         % check_attacker.pl --display=referrer  # default is to display the user agent
```
