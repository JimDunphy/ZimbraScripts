#!/bin/bash

#
# Author: Jim Dunphy
# License (ISC): It's yours. Enjoy
# 4/16/2023
#
#
# Caveat: Needs to be run as root
#        installs a stored procedure call that remains until you drop it from the database.
#
# Note:
#   speeds it up substantically from 46 seconds to 2.3 seconds on tests here
#
#
# Sample output:
#
#User                                                         Total Messages   Total Folders    Total Contacts  
#--------------------------------------------------------------------------------------------------------------
#user1@xxxxxxxxxxxxxx.com                                     0                17               0               
#user2@xxxxxxxxxxxxxx.com                                     0                16               1               
#user3@xxxxxxxxxxxxxx.com                                     19014            115              2314      
#...
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

dropStoredProcedure() {
su - zimbra -c "mysql <<'EOF'
USE zimbra;
DROP PROCEDURE getUserStats;
EOF"
}

addStoredProcedure() {
su - zimbra -c "mysql <<'EOF'

USE zimbra;

DELIMITER //
CREATE PROCEDURE getUserStats()
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE current_group_id INT;
    DECLARE cur CURSOR FOR SELECT DISTINCT group_id FROM mailbox;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    DROP TEMPORARY TABLE IF EXISTS temp_user_stats;
    CREATE TEMPORARY TABLE temp_user_stats (
        User VARCHAR(255),
        TotalMessages INT,
        TotalFolders INT,
        TotalContacts INT
    );

    OPEN cur;

    read_loop: LOOP
        FETCH cur INTO current_group_id;
        IF done THEN
            LEAVE read_loop;
        END IF;

        SET @query = CONCAT('
            INSERT INTO temp_user_stats
            SELECT mbox.comment AS User,
                   SUM(IF(mi.type = 5, 1, 0)) AS TotalMessages,
                   SUM(IF(mi.type = 1, 1, 0)) AS TotalFolders,
                   SUM(IF(mi.type = 6, 1, 0)) AS TotalContacts
            FROM mailbox AS mbox
            JOIN mboxgroup', current_group_id, '.mail_item AS mi
            ON mbox.id = mi.mailbox_id
            GROUP BY mbox.id, mbox.comment;
        ');

        PREPARE stmt FROM @query;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;

    CLOSE cur;

    SELECT * FROM temp_user_stats;
END//
DELIMITER ;
EOF"

}

usage() {
  echo "

    Note: Stored procedure call must be added before results can be generated
          where it will remain with the database until manually dropped.

      % su - 
      # zmShowUserCounts.sh --add		# one time only
      # zmShowUserCounts.sh		        # generate results
      # zmShowUserCounts.sh --help
      # zmShowUserCounts.sh --version
      # zmShowUserCounts.sh --drop


   If you want to remove this stored procedure, use the --drop option

      # zmShowUserCounts.sh --drop

  "
}

# need to run as root to make su to zimbra transparent
ID=`id -u`
if [ "x$ID" != "x0" ]; then
  echo "Run as root!"
  exit 1
fi


args=$(getopt -l "add,drop,help,version" -o "adhv" -- "$@")

eval set -- "$args"

while [ $# -ge 1 ]; do
        case "$1" in
                --)
                    # No more options left.
                    shift
                    break
                   ;;
                -a | --add)
                      addStoredProcedure
                      exit
                      ;;
                -d | --drop)
                      dropStoredProcedure
                      exit
                      ;;
                -v | --version)
                      echo "Version 0.2"
                      exit
                      ;;
                -h|--help)
                        usage
                        exit 0
                        ;;
        esac

        shift
done


# Define a command string to be executed as the zimbra user
commands=$(cat <<'EOF'
zimbra_mysql_password=$(zmlocalconfig -s zimbra_mysql_password | awk '{print $3}')

printf "%-60s %-16s %-16s %-16s\n" "User" "Total Messages" "Total Folders" "Total Contacts"
echo "-------------------------------------------------------------------------------------------------------------"

IFS=$'\n'
rows=$(mysql --user=zimbra --password=$zimbra_mysql_password -N -e "use zimbra;CALL getUserStats()")
for row in $rows; do
  username=$(echo "$row" | awk '{print $1}')
  total_messages=$(echo "$row" | awk '{print $2}')
  total_folders=$(echo "$row" | awk '{print $3}')
  total_contacts=$(echo "$row" | awk '{print $4}')
  printf "%-60s %-16s %-16s %-16s\n" "$username" "$total_messages" "$total_folders" "$total_contacts"
done
EOF
)

# Execute the commands as the zimbra user
su - zimbra -c "$commands"
