#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs -d '\n')
fi

docker-compose up --build -d

while ! mysqladmin ping -h $MASTER_HOST --silent; do
	sleep 1
done

# Process on Master
priv_stmt_master="GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;" && docker exec mysql_master sh -c "mysql -u root -e \"$priv_stmt_master\"" && echo "Master Successfully Configured"

MS_STATUS=$(docker exec mysql_master sh -c 'mysql -u root -e "SHOW MASTER STATUS\G"')
CURRENT_LOG=$(echo "$MS_STATUS" | grep "File:" | awk '{print $2}')
CURRENT_POS=$(echo "$MS_STATUS" | grep "Position:" | awk '{print $2}')

while ! mysqladmin ping -h $SLAVE_HOST_1 --silent; do
	sleep 1
done

while ! mysqladmin ping -h $SLAVE_HOST_2 --silent; do
	sleep 1
done

# Process on Slave
start_slave_stmt="CHANGE MASTER TO MASTER_HOST='$MASTER_HOST',MASTER_USER='$MYSQL_USER',MASTER_PASSWORD='$MYSQL_PASSWORD',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;" && docker exec mysql_slave-1 sh -c "mysql -u root --execute=\"$start_slave_stmt\"" && docker exec mysql_slave-2 sh -c "mysql -u root --execute=\"$start_slave_stmt\"" && echo "Slave Successfully Configured"

# SYNC Master and Slave DB
db_synch="CREATE DATABASE $MYSQL_DATABASE;" && docker exec mysql_master sh -c "mysql -u root -e \"$db_synch\"" && echo "Database Synchronized"

# #Check Slave Status
# docker exec mysql_slave-1 sh -c "mysql -u root -e 'SHOW SLAVE STATUS\G'" && docker exec mysql_slave-2 sh -c "mysql -u root -e 'SHOW SLAVE STATUS\G'"




