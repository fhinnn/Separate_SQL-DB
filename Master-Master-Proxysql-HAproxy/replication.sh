#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs -d '\n')
fi

docker-compose up --build -d

while ! mysqladmin ping -h $MASTER_HOST_1 --silent; do
	sleep 1
done

while ! mysqladmin ping -h $MASTER_HOST_2 --silent; do
	sleep 1
done

# Process on Master
priv_stmt_master="GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;" && docker exec mysql_master-1 sh -c "mysql -u root -e \"$priv_stmt_master\"" && echo "Master-1 Successfully Configured"
priv_stmt_master="GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_USER'@'%'; FLUSH PRIVILEGES;" && docker exec mysql_master-2 sh -c "mysql -u root -e \"$priv_stmt_master\"" && echo "Master-2 Successfully Configured"

MS_STATUS_1=$(docker exec mysql_master-1 sh -c 'mysql -u root -e "SHOW MASTER STATUS\G"')
CURRENT_LOG_1=$(echo "$MS_STATUS_1" | grep "File:" | awk '{print $2}')
CURRENT_POS_1=$(echo "$MS_STATUS_1" | grep "Position:" | awk '{print $2}')

start_master_stmt_2="STOP SLAVE; CHANGE MASTER TO MASTER_HOST='$MASTER_HOST_1',MASTER_USER='$MYSQL_USER',MASTER_PASSWORD='$MYSQL_PASSWORD',MASTER_LOG_FILE='$CURRENT_LOG_1',MASTER_LOG_POS=$CURRENT_POS_1; START SLAVE;"
docker exec mysql_master-2 sh -c "mysql -u root --execute=\"$start_master_stmt_2\""

MS_STATUS_2=$(docker exec mysql_master-2 sh -c 'mysql -u root -e "SHOW MASTER STATUS\G"')
CURRENT_LOG_2=$(echo "$MS_STATUS_2" | grep "File:" | awk '{print $2}')
CURRENT_POS_2=$(echo "$MS_STATUS_2" | grep "Position:" | awk '{print $2}')

# Configure Master-Master Replication
start_master_stmt_1="STOP SLAVE; CHANGE MASTER TO MASTER_HOST='$MASTER_HOST_2',MASTER_USER='$MYSQL_USER',MASTER_PASSWORD='$MYSQL_PASSWORD',MASTER_LOG_FILE='$CURRENT_LOG_2',MASTER_LOG_POS=$CURRENT_POS_2; START SLAVE;"
docker exec mysql_master-1 sh -c "mysql -u root --execute=\"$start_master_stmt_1\""

echo "Master-Master Replication Successfully Configured"

while ! mysqladmin ping -h $SLAVE_HOST_1 --silent; do
	sleep 1
done

while ! mysqladmin ping -h $SLAVE_HOST_2 --silent; do
	sleep 1
done

# Process on Slave
docker exec mysql_master-1 sh -c "mysql -u root --execute=\"STOP SLAVE\"" && docker exec mysql_master-2 sh -c "mysql -u root --execute=\"STOP SLAVE\""
start_slave_stmt_1="CHANGE MASTER TO MASTER_HOST='$MASTER_HOST_1',MASTER_USER='$MYSQL_USER',MASTER_PASSWORD='$MYSQL_PASSWORD',MASTER_LOG_FILE='$CURRENT_LOG_1',MASTER_LOG_POS=$CURRENT_POS_1; START SLAVE;" && docker exec mysql_slave-1 sh -c "mysql -u root --execute=\"$start_slave_stmt_1\"" && echo "Slave-1 Successfully Configured"
start_slave_stmt_2="CHANGE MASTER TO MASTER_HOST='$MASTER_HOST_2',MASTER_USER='$MYSQL_USER',MASTER_PASSWORD='$MYSQL_PASSWORD',MASTER_LOG_FILE='$CURRENT_LOG_2',MASTER_LOG_POS=$CURRENT_POS_2; START SLAVE;" && docker exec mysql_slave-2 sh -c "mysql -u root --execute=\"$start_slave_stmt_2\"" && echo "Slave-2 Successfully Configured"
docker exec mysql_master-1 sh -c "mysql -u root --execute=\"START SLAVE\"" && docker exec mysql_master-2 sh -c "mysql -u root --execute=\"START SLAVE\""


# SYNC Master and Slave DB
db_synch="CREATE DATABASE $MYSQL_DATABASE;" && docker exec mysql_master-1 sh -c "mysql -u root -e \"$db_synch\"" && echo "Database Synchronized"

# #Check Slave Status
# docker exec mysql_slave-1 sh -c "mysql -u root -e 'SHOW SLAVE STATUS\G'" && docker exec mysql_slave-2 sh -c "mysql -u root -e 'SHOW SLAVE STATUS\G'"




