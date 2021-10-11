#!/bin/bash

set -x

is_replica=$(gitlab-psql --no-align --tuples-only --command='SELECT pg_is_in_recovery();')

if [[ "${is_replica}" != 'f' ]]; then
    echo "Aborting -- this is a replica!"
    exit
fi

gitlab-psql \
  -c "set vacuum_cost_delay = 0" \
  -c "\\timing on" \
  -c "analyze (verbose, skip_locked) issues" \
  -c "analyze (verbose, skip_locked) notes" 2>&1 
