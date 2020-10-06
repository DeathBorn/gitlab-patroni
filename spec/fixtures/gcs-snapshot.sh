#!/bin/bash

exec &> >(tee -a "/var/log/gitlab/postgresql/gcs-snapshot-$(date +%Y%m%d-%H%M%S).log")

# GitLab Job metric settings
# https://gitlab.com/gitlab-com/runbooks/-/blob/master/docs/uncategorized/job_completion.md
RESOURCE='patroni-gcs-snapshot'
MAX_AGE='1800' # 30 minutes
PROM_SHARD='shard/main'
PROM_TIER='tier/db'
PROM_TYPE='type/patroni'

pushgateway(){
  local url="http://localhost:9091/metrics/job/${RESOURCE}/${PROM_SHARD}/${PROM_TIER}/${PROM_TYPE}"
  curl -siv --data-binary @- "${url}"
}


# Push start of snapshot to pushgateway
cat <<PROM | pushgateway
# HELP gitlab_job_start_timestamp_seconds The start time of the job.
# TYPE gitlab_job_start_timestamp_seconds gauge
gitlab_job_start_timestamp_seconds{resource="${RESOURCE}"} $(date +%s)
# HELP gitlab_job_success_timestamp_seconds The time the job succeeded.
# TYPE gitlab_job_success_timestamp_seconds gauge
gitlab_job_success_timestamp_seconds{resource="${RESOURCE}"} 0
# HELP gitlab_job_max_age_seconds How long the job is allowed to run before marking it failed.
# TYPE gitlab_job_max_age_seconds gauge
gitlab_job_max_age_seconds{resource="${RESOURCE}"} ${MAX_AGE}
# HELP gitlab_job_failed Boolean status of the job.
# TYPE gitlab_job_failed gauge
gitlab_job_failed{resource="${RESOURCE}"} 0
PROM

# Start with fresh FIFOs
rm -f /tmp/snapshot-start-backup /tmp/snapshot-stop-backup
mkfifo /tmp/snapshot-start-backup /tmp/snapshot-stop-backup &>/dev/null

# pg_{start,stop}_backup have to be executed on the same connection
gitlab-psql -f /tmp/snapshot-start-backup -f /tmp/snapshot-stop-backup &

echo "SELECT pg_start_backup('GCS snapshot', TRUE, FALSE);" > /tmp/snapshot-start-backup

gcloud auth activate-service-account --key-file=/etc/gitlab/gcs-snapshot.json
gcloud config set project gitlab-rspec
gcloud config set compute/zone us-east-66c
gcloud compute disks snapshot patroni-rspec-06-data --description="Snapshot created by $0 on $(date)" || {
  echo "Snapshot failed!"

  cat <<PROM | pushgateway
# HELP gitlab_job_failed Boolean status of the job.
# TYPE gitlab_job_failed gauge
gitlab_job_failed{resource="${RESOURCE}"} 1
PROM

  exit 1
}

echo "SELECT pg_stop_backup(FALSE, FALSE);" > /tmp/snapshot-stop-backup

# Push finish of snapshot to pushgateway
cat <<PROM | pushgateway
# HELP gitlab_job_success_timestamp_seconds The time the job succeeded.
# TYPE gitlab_job_success_timestamp_seconds gauge
gitlab_job_success_timestamp_seconds{resource="${RESOURCE}"} $(date +%s)
PROM
