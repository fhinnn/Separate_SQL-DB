# Separatedb-proxysql

Separatedb-proxysql is a simple script automating the process of setting up a separatedb environment with proxysql as the load balancer. The script is written in bash.

## Installation

1. Clone the repository

```bash
git clone https://github.com/fhinnn/Separatedb-proxysql.git
```

2. Change directory

```bash
cd Separatedb-proxysql/Master-Master # for master-master replication (2 db master and 2 db slave)
cd Separatedb-proxysql/Master-Slave # for master-slave replication (1 db master and 2 db slave)
```

3. Run the script

```bash
bash replication.sh && bash proxy.sh
```
