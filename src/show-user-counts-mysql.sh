#!/bin/bash

#
# Author: ChatGBT-4
# Human: Jim Dunphy 
# License (ISC): It's yours. Enjoy
# 4/15/2023
#
# usage: show-user-counts.sh  # needs to run as root user
#
#User                                                         Total Messages   Total Folders    Total Contacts  
#--------------------------------------------------------------------------------------------------------------
#user1@xxxxxxxxxxxxxx.com                                     0                17               0               
#user2@xxxxxxxxxxxxxx.com                                     0                16               1               
#user3@xxxxxxxxxxxxxx.com                                     19014            115              2314      
#...
#user4@xxxxxxxxxxxxxx.com                                     19014            115              2314      
#
#
# Folder (type = 1): Represents a folder in the mailbox.
# Tag (type = 2): Represents a tag that can be associated with items in the mailbox.
# Conversation (type = 3): Represents a conversation, which is a group of related email messages.
# Message (type = 5): Represents an individual email message.
# Contact (type = 6): Represents a contact in the user's address book.
# Document (type = 7): Represents a document saved in the user's mailbox.
# Appointment (type = 11): Represents a calendar appointment.
# Task (type = 13): Represents a task in the user's task list.
# Wiki (type = 14): Represents a wiki page in the user's mailbox.
# Chat (type = 15): Represents a chat message in the user's mailbox.
#
# These are the most common types you may encounter when working with Zimbra's MySQL database. The 
# type values are used to identify the specific kind of item in the mail_item table.
#

# need to run as root to make su to zimbra transparent
ID=`id -u`
if [ "x$ID" != "x0" ]; then
  echo "Run as root!"
  exit 1
fi

# Define a command string to be executed as the zimbra user
commands=$(cat <<EOF
zimbra_mysql_password=\$(zmlocalconfig -s zimbra_mysql_password | awk '{print \$3}')
user_mailbox_ids=\$(mysql --user=zimbra --password=\$zimbra_mysql_password -N -e "USE zimbra; SELECT id, comment FROM mailbox;")

printf "%-60s %-16s %-16s %-16s\n" "User" "Total Messages" "Total Folders" "Total Contacts"
printf "%.0s-" {1..110} 
printf "\n"

while read -r id comment; do
    group_id=\$(mysql --user=zimbra --password=\$zimbra_mysql_password -N -e "USE zimbra; SELECT group_id FROM mailbox WHERE id = \$id;")
    total_messages=\$(mysql --user=zimbra --password=\$zimbra_mysql_password -N -e "USE mboxgroup\$group_id; SELECT COUNT(*) FROM mail_item WHERE type = 5;")
    total_folders=\$(mysql --user=zimbra --password=\$zimbra_mysql_password -N -e "USE mboxgroup\$group_id; SELECT COUNT(*) FROM mail_item WHERE type = 1;")
    total_contacts=\$(mysql --user=zimbra --password=\$zimbra_mysql_password -N -e "USE mboxgroup\$group_id; SELECT COUNT(*) FROM mail_item WHERE type = 6;")
    printf "%-60s %-16s %-16s %-16s\n" "\$comment" "\$total_messages" "\$total_folders" "\$total_contacts"
done <<< "\$user_mailbox_ids"
EOF
)

# Execute the commands as the zimbra user
su - zimbra -c "$commands"
