
#!/bin/bash

set -x

gitlab-psql \
  -c "\\timing on" \
  -c "select pg_wait_sampling_reset_profile();" 2>&1 