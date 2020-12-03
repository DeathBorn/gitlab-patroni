#!/bin/bash


exec &> >(tee -a "/var/log/gitlab/postgresql/post-failover-maintenance-$(date +%Y%m%d-%H%M%S).log")
set -x

[[ "$2" == "master" ]] || exit

for i in $(seq 1 5); do
  gitlab-psql -tc 'SELECT pg_is_in_recovery()' | grep 'f' && break
  sleep 60
done

vacuumdb -h localhost -p 5432 -d gitlabhq_production -U gitlab-superuser-20200604_224119 --analyze-only --jobs=16