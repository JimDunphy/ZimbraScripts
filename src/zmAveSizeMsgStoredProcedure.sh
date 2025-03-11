#!/bin/bash

#
# Author: Jim Dunphy (2/28/2025)
#
# Refernce: https://forums.zimbra.org/viewtopic.php?t=73274
#
#
# usage: zmAveSizeMsgStoredProcedure.sh 
#    Calculating average email size...
#    +-----------------------+
#    | average_email_size_kb |
#    +-----------------------+
#    |                111.93 |
#    +-----------------------+
#
# Caveat: must be run as the zimbra user
#

# Check if the user is zimbra
if [ "$(whoami)" != "zimbra" ]; then
  echo "Please run as zimbra"
  exit 1
fi

# Zimbra MySQL credentials
ZMYSQL_USER="zimbra"
ZMYSQL_PASSWORD="your_mysql_password"  # Replace with your Zimbra MySQL password
ZMYSQL_HOST="localhost"

# Function to install the stored procedure
install_stored_procedure() {
  #mysql -h $ZMYSQL_HOST -u $ZMYSQL_USER -p$ZMYSQL_PASSWORD mysql <<EOF
  mysql -u $ZMYSQL_USER mysql <<EOF
  DELIMITER //

CREATE PROCEDURE CalculateAverageEmailSize()
BEGIN
  DECLARE done INT DEFAULT 0;
  DECLARE db_name VARCHAR(64);
  DECLARE total_size BIGINT DEFAULT 0;
  DECLARE total_emails BIGINT DEFAULT 0;
  DECLARE avg_size_kb DECIMAL(10, 2);

  -- Cursor to loop through all mboxgroup* databases
  DECLARE db_cursor CURSOR FOR
    SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name LIKE 'mboxgroup%';

  -- Handler for when no more databases are found
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  OPEN db_cursor;

  db_loop: LOOP
    FETCH db_cursor INTO db_name;
    IF done THEN
      LEAVE db_loop;
    END IF;

    -- Query the mail_item table in the current database
    SET @query = CONCAT(
      'SELECT COALESCE(SUM(size), 0), COALESCE(COUNT(*), 0) INTO @size, @count ',
      'FROM ', db_name, '.mail_item ',
      'WHERE type = 5;'
    );

    PREPARE stmt FROM @query;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Accumulate total size and email count
    SET total_size = total_size + @size;
    SET total_emails = total_emails + @count;
  END LOOP;

  CLOSE db_cursor;

  -- Calculate the average email size in KB
  IF total_emails > 0 THEN
    SET avg_size_kb = (total_size / total_emails) / 1024;
    SELECT avg_size_kb AS average_email_size_kb;
  ELSE
    SELECT 'No emails found in any mboxgroup database!' AS message;
  END IF;
END //

DELIMITER ;
EOF
}

# Function to remove the stored procedure
remove_stored_procedure() {
  #mysql -h $ZMYSQL_HOST -u $ZMYSQL_USER -p$ZMYSQL_PASSWORD mysql -e "DROP PROCEDURE IF EXISTS CalculateAverageEmailSize;"
  mysql -u $ZMYSQL_USER mysql -e "DROP PROCEDURE IF EXISTS CalculateAverageEmailSize;"
}

# Install the stored procedure
install_stored_procedure

# Call the stored procedure and display the results
echo "Calculating average email size..."
#mysql -h $ZMYSQL_HOST -u $ZMYSQL_USER -p$ZMYSQL_PASSWORD mysql -e "CALL CalculateAverageEmailSize();"
mysql -u $ZMYSQL_USER  mysql -e "CALL CalculateAverageEmailSize();"

# Remove the stored procedure (optional)
remove_stored_procedure
