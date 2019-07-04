#!/bin/sh
#
# usage: dump_trained_spam.sh
#
#Return-Path: bounces+10719421-d795-user=example@u10719421.wl172.sendgrid.net
#X-Spam-Status: No, score=2.855 required=4.8 tests=[BAYES_95=3,
#       DKIM_SIGNED=0.1, DKIM_VALID=-0.1, DKIM_VALID_AU=-0.1,
#       HEADER_FROM_DIFFERENT_DOMAINS=0.25, HTML_MESSAGE=0.001,
#       HTTP_IN_BODY=0.1, J_IMG_NO_EXTENS=0.5, J_RCVD_IN_HOSTKARMA_YEL=0.003,
#       J_URI_DOMAIN_BAD=0.1, MAILING_LIST_MULTI=-1,
#       RCVD_IN_DNSWL_NONE=-0.0001, SPF_HELO_NONE=0.001]
#       autolearn=no autolearn_force=no
#From: Rose Smith <rose@kreativemachinez.co.in>
#Subject: =?UTF-8?B?8J+GlQ==?= Website Development Proposal & Digital Marketing
#To: "user@example.com" <user@example.com>
#-----------------------------
#Return-Path: alexa@questmso.com
#X-Spam-Status: No, score=1.728 required=4.8 tests=[BAYES_50=0.8,
#       DKIM_SIGNED=0.1, DKIM_VALID=-0.1, DKIM_VALID_AU=-0.1,
#       HTML_MESSAGE=0.001, HTTP_IN_BODY=0.1, J_DOCTYPE_MISSING=0.5,
#       MIME_HTML_MOSTLY=0.428, RCVD_IN_DNSWL_NONE=-0.0001,
#       SPF_HELO_PASS=-0.001] autolearn=no autolearn_force=no
#From: "QuestMSO LLC" <Alexa@questmso.com>
#To: <user@example>
#Subject: Can You Help Me Please!
#...
#...
#
# 6/14/2019 - JAD

# %%% if you only want to look at scores < 4 vs everything
#for file in `grep X-Spam-Score /tmp/zmtrain*spam*/* | egrep ':\s+(-|0\.|1\.|2\.|3\.)' | awk -F: '{print }' | sort -u | awk -F: '{print $1}'`
for file in `grep X-Spam-Score /tmp/zmtrain*spam*/* | awk -F: '{print }' | sort -u | awk -F: '{print $1}'`
do
  cat $file | inspect_mail.pl
  echo "-----------------------------"
done

