#!/bin/bash

set -x

[[ "$2" == "master" ]] || exit

for i in $(seq 1 5); do
  gitlab-psql -tc 'SELECT pg_is_in_recovery()' | grep 'f' && break
  sleep 60
done

gitlab-psql --command="ANALYZE namespaces;"
