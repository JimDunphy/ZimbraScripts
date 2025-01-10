#!/bin/bash
#
# Ref: https://forums.zimbra.org/viewtopic.php?p=314569#p314569
#
# Author: ChatGPT 4o
# Human: Jim Dunphy - jad@aesir.com
#
# Check for ZBUG-4613 where disk sizes can expan because IMAP duplication and dumpster expiring out deleted
# email.
#
# Caveat: Should be run as the zimbra user
#

# Check if an email address is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <email-address>"
  exit 1
fi

# Set the mailbox email
mailbox="$1"

# Extract the mailbox ID using zmprov
mailboxid=$(/opt/zimbra/bin/zmprov gmi "$mailbox" | grep "mailboxId" | awk '{print $2}')

# Validate if mailbox ID was retrieved
if [ -z "$mailboxid" ]; then
  echo "Error: Could not retrieve mailbox ID for $mailbox."
  exit 2
fi

# Calculate the mailbox group
group=$(expr "$mailboxid" % 100)

# Validate the group calculation
if [ -z "$group" ]; then
  echo "Error: Could not calculate mailbox group."
  exit 3
fi

# Query the MariaDB database for the count of mail items in the dumpster
mysql_output=$(mysql -N -B mboxgroup"$group" -e "SELECT COUNT(*) FROM mail_item_dumpster WHERE mailbox_id=$mailboxid;")

# Validate the database query
if [ $? -ne 0 ]; then
  echo "Error: Database query failed."
  exit 4
fi

# Output the results
echo "Mailbox ID: $mailboxid"
echo "Mailbox Group: mboxgroup$group"
echo "Count of items in dumpster: $mysql_output"

