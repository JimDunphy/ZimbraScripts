#!/bin/sh
#
# Show users which have mobile syunc activated
#
# run as root
#
# usage: ./show-mobile.sh 
# +----------------+------------+---------------------+-------------+-------+------+
# | comment        | mailbox_id | device_id           | device_type | model | os   |
# +----------------+------------+---------------------+-------------+-------+------+
# | jd@example.com |          3 | android946699536255 | Android     | NULL  | NULL |
# +----------------+------------+---------------------+-------------+-------+------+
# 

su - zimbra -c "mysql -e 'select mb.comment, md.mailbox_id, md.device_id, md.device_type, md.model, md.os from zimbra.mobile_devices md INNER JOIN zimbra.mailbox mb ON md.mailbox_id = mb.id ;'"

