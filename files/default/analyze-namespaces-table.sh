#!/bin/bash

set -x

is_replica=$(gitlab-psql --no-align --tuples-only --command='SELECT pg_is_in_recovery();')

if [[ "${is_replica}" != 'f' ]]; then
    echo "Aborting -- this is a replica!"
    exit
fi

gitlab-psql --command="ANALYZE namespaces;"
