#!/bin/sh

PGUSERNAME=$(sudo /bin/cat /var/opt/gitlab/postgresql/.pgpass | cut -d':' -f4)
PGPASSWORD=$(sudo /bin/cat /var/opt/gitlab/postgresql/.pgpass | cut -d':' -f5)
export PGPASSWORD
CMD="/opt/patroni/bin/pg_activity --username=${PGUSERNAME} --dbname=gitlabhq_production"
$CMD
