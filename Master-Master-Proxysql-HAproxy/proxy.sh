#!/bin/bash

if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs -d '\n')
fi

while ! mysqladmin ping -h $PROXY_HOST -P$PROXY_ADMIN_PORT --silent; do
	sleep 1
done

# Process on Proxy
proxy_stmt_1="INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES (1, '$HAPROXY_MASTER', 3306, 1);
INSERT INTO mysql_servers (hostgroup_id, hostname, port, weight) VALUES (2, '$HAPROXY_SLAVE', 3306, 1);"

proxy_stmt_2="INSERT INTO mysql_users (username, password, default_hostgroup) VALUES ('$PROXY_USER', '$PROXY_PASSWORD', 1);"

proxy_stmt_3="INSERT INTO mysql_query_rules (rule_id, active, username, match_digest, destination_hostgroup, apply) VALUES (1,1,'$PROXY_USER','^select',2,1);"

proxy_stmt_4="set mysql-server_version='8.0.26';
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;
SET admin-web_enabled='true';
LOAD ADMIN VARIABLES TO RUNTIME;
SAVE ADMIN VARIABLES TO DISK;"


# SET VARIABLES
docker exec proxysql-server sh -c "mysql -u $PROXY_ADMIN_USER -p$PROXY_ADMIN_PASSWORD -P$PROXY_ADMIN_PORT -e \"$proxy_stmt_1\"" && echo "Hostgroup Configured"
docker exec proxysql-server sh -c "mysql -u $PROXY_ADMIN_USER -p$PROXY_ADMIN_PASSWORD -P$PROXY_ADMIN_PORT -e \"$proxy_stmt_2\"" && echo "User Configured"
docker exec proxysql-server sh -c "mysql -u $PROXY_ADMIN_USER -p$PROXY_ADMIN_PASSWORD -P$PROXY_ADMIN_PORT -e \"$proxy_stmt_3\"" && echo "Query Rule Configured"
docker exec proxysql-server sh -c "mysql -u $PROXY_ADMIN_USER -p$PROXY_ADMIN_PASSWORD -P$PROXY_ADMIN_PORT -e \"$proxy_stmt_4\"" && echo "Mysql Version & Monitor Configured"


# Save Changes
proxy_stmt_4="LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;"

docker exec proxysql-server sh -c "mysql -u $PROXY_ADMIN_USER -p$PROXY_ADMIN_PASSWORD -P$PROXY_ADMIN_PORT -e \"$proxy_stmt_4\"" && echo "Changes Saved"

# Proxy Apply
proxy_stmt_5="CREATE USER '$PROXY_USER'@'%' IDENTIFIED BY '$PROXY_PASSWORD'; 
GRANT ALL PRIVILEGES ON $MYSQL_DATABASE.* TO '$PROXY_USER'@'%';
FLUSH PRIVILEGES;
CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor';
GRANT SELECT ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;"


docker exec mysql_master-1 sh -c "mysql -u root -e \"$proxy_stmt_5\"" && echo "Proxy Connected"