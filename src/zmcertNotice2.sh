#!/bin/bash
# ============================================================================
# zmcertNotice.sh - Certificate renewal notification script
# 
# Sends consolidated email notification when Let's Encrypt certificates are 
# approaching renewal time or have expired

#
# Notify us X days in advance of pending renewal for acme.sh letsencrypt renewal.
#
# Verify you have this script in your zimbra crontab entry. Should look something like this.
#
# # ZIMBRAEND -- DO NOT EDIT ANYTHING BETWEEN THIS LINE AND ZIMBRASTART
#
# 18 0 * * * "/opt/zimbra/.acme.sh"/acme.sh --cron --home "/opt/zimbra/.acme.sh" > /dev/null
# 17 0 * * * /usr/local/bin/zmcertNotice.sh > /dev/null 2>&1
#
# Version 3.05 changed the date format for ./acme.sh --list 
#
# You need to supply your email at STEP 1. There is only 1 step :-)
#
#

# ============================================================================

# Set path to ensure acme.sh is available
export PATH=~/.acme.sh:/bin:/usr/bin:/usr/sbin:/usr/local:$PATH

# Configuration
LOCAL_HOST=$(hostname)
EMAIL="XXX@XXXX.com"    # %%% STEP 1: CHANGE THIS
SENDMAIL="/opt/zimbra/common/sbin/sendmail"
NOTIFICATION_DAYS=1  # Days before renewal to send notification

# Function to convert date to seconds since epoch
date_to_seconds() {
    date +%s -d "$1"
}

# Create a temporary file to store certificates needing attention
TEMP_FILE=$(mktemp)
trap 'rm -f $TEMP_FILE' EXIT

# Get current date in seconds
current_date=$(date -u)
current_seconds=$(date_to_seconds "$current_date")
future_seconds=$(date_to_seconds "$current_date+$NOTIFICATION_DAYS days")

# Get the list of domains and process each one
acme.sh --list | tail -n +2 | while read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Extract Main Domain from first column
    domain=$(echo "$line" | awk '{print $1}')
    
    # Extract renewal date (last column)
    renewal_date=$(echo "$line" | awk '{print $NF}')
    
    # Convert T and Z to spaces for date command compatibility
    formatted_renewal_date=$(echo "$renewal_date" | sed 's/T/ /' | sed 's/Z//')
    
    # Calculate seconds for renewal time
    renewal_seconds=$(date_to_seconds "$formatted_renewal_date")
    
    # Determine if certificate needs attention
    if (( current_seconds > renewal_seconds )); then
        # Certificate is expired
        days_expired=$(( (current_seconds - renewal_seconds) / 86400 ))
        echo "$domain – EXPIRED $days_expired day(s) ago (renew was $(echo $renewal_date | sed 's/T.*Z//'))" >> "$TEMP_FILE"
    elif (( future_seconds > renewal_seconds )); then
        # Certificate is approaching renewal
        days_until_renewal=$(( (renewal_seconds - current_seconds) / 86400 ))
        echo "$domain – Renewal in $days_until_renewal day(s) (renew date: $(echo $renewal_date | sed 's/T.*Z//'))" >> "$TEMP_FILE"
    fi
done

# Check if we have any certificates needing attention
if [ -s "$TEMP_FILE" ]; then
    # Build the email message
    subject="Certificate renewal alert for $LOCAL_HOST"
    
    message="Hello,

The following Let's Encrypt certificates on $LOCAL_HOST need attention:

"
    
    # Add each certificate as a bullet point
    while read -r cert; do
        message+="  • $cert
"
    done < "$TEMP_FILE"
    
    message+="
This notice will repeat nightly until each certificate is renewed."
    
    # Send the email
    echo "Subject: $subject

$message" | "$SENDMAIL" "$EMAIL"
    
    echo "Notification sent for $(wc -l < "$TEMP_FILE") certificates"
fi

exit 0
