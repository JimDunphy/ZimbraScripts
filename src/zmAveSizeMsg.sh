#!/bin/bash

#
# Author: Jim Dunphy (2/28/2025)
#
# Refernce: https://forums.zimbra.org/viewtopic.php?t=73274
#
# Note: If you have 100 users, it will query 100 tables.
#       If you require a faster version then use which is very fast.
#
#       zmAveSizeMsgStoredProcedure.sh 
#
# usage: zmAveSizeMsg.sh
# 
# Determine the average size message this zimbra server handles.
#
# Processing database: mboxgroup1 (this may take a moment...)
# Processing database: mboxgroup10 (this may take a moment...)
# Processing database: mboxgroup11 (this may take a moment...)
# ...
# Processing database: mboxgroupN (this may take a moment...)
# Overall average email size for the entire system: 110.41 KB
#
# Caveat: Must be run as the zimbra user as we need the environmental variables for mysql

# Check if the user is zimbra
if [ "$(whoami)" != "zimbra" ]; then
  echo "Please run as zimbra"
  exit 1
fi

# Zimbra MySQL credentials
ZMYSQL_USER="zimbra"
ZMYSQL_PASSWORD="your_mysql_password"  # Replace with your Zimbra MySQL password
ZMYSQL_HOST="localhost"

# Function to calculate average using awk
calculate_average() {
  local total_size=$1
  local total_emails=$2
  echo "$total_size $total_emails" | awk '{printf "%.2f", ($1 / $2) / 1024}'
}

# Get the list of all mboxgroup databases
#MBOXGROUPS=$(mysql -h $ZMYSQL_HOST -u $ZMYSQL_USER -p$ZMYSQL_PASSWORD -e "SHOW DATABASES LIKE 'mboxgroup%';" -s -N)
MBOXGROUPS=$(mysql -u $ZMYSQL_USER -e "SHOW DATABASES LIKE 'mboxgroup%';" -s -N)

# Check if mboxgroup databases exist
if [ -z "$MBOXGROUPS" ]; then
  echo "No mboxgroup databases found!"
  exit 1
fi

# Initialize variables for total size and total email count
TOTAL_SIZE=0
TOTAL_EMAILS=0

# Loop through each mboxgroup database
for DB in $MBOXGROUPS; do
  echo "Processing database: $DB (this may take a moment...)"

  # Query the total size and email count for the current mboxgroup
  #RESULTS=$(mysql -h $ZMYSQL_HOST -u $ZMYSQL_USER -p$ZMYSQL_PASSWORD -D $DB -e "SELECT SUM(size), COUNT(*) FROM mail_item WHERE type = 5;" -s -N)
  RESULTS=$(mysql -u $ZMYSQL_USER -D $DB -e "SELECT SUM(size), COUNT(*) FROM mail_item WHERE type = 5;" -s -N)

  # Extract the total size and email count from the results
  SIZE=$(echo "$RESULTS" | awk '{print $1}')
  COUNT=$(echo "$RESULTS" | awk '{print $2}')

  # Accumulate total size and email count
  TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
  TOTAL_EMAILS=$((TOTAL_EMAILS + COUNT))
done

# Calculate the overall average email size in KB
if [ $TOTAL_EMAILS -gt 0 ]; then
  OVERALL_AVG=$(calculate_average $TOTAL_SIZE $TOTAL_EMAILS)
  echo "Overall average email size for the entire system: $OVERALL_AVG KB"
else
  echo "No emails found in any mboxgroup database!"
fi
