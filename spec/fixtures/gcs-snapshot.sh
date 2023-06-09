#!/bin/bash

exec &> >(tee -a "/var/log/gitlab/postgresql/gcs-snapshot.log")

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

stopbackup() {
  echo "SELECT pg_stop_backup(FALSE, FALSE);" > /tmp/snapshot-stop-backup
  # Wait for gitlab-psql to return from the background
  wait -n %1
}

echo "============== $(date +%Y%m%d-%H%M%S)"

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

# Since gitlab-psql is in the background, gcloud snapshot could start even before pg_start_backup has returned,
# hence we add the COPY query that would run after pg_start_backup returns and leave a temp file as an evidence of execution.
rm -f /tmp/ready-to-snapshot
echo "SELECT pg_start_backup('GCS snapshot', TRUE, FALSE); COPY (SELECT 1) TO '/tmp/ready-to-snapshot'" > /tmp/snapshot-start-backup

loop_max_time=$(date -d '5 minutes' +%s)
while [[ ! -f /tmp/ready-to-snapshot ]]; do
  if [[ $(date +%s) -gt $loop_max_time ]]; then
    echo "Loop checking for /tmp/ready-to-snapshot ran for 5 minutes, exiting ..."
    exit 1
  fi

  sleep 0.5
done

gcloud auth activate-service-account --key-file=/etc/gitlab/gcs-snapshot.json
gcloud compute disks snapshot patroni-rspec-06-data --project=gitlab-rspec --zone=us-east-66c --description="Snapshot created by $0 on $(date)" || {
  echo "Snapshot failed!"

  cat <<PROM | pushgateway
# HELP gitlab_job_failed Boolean status of the job.
# TYPE gitlab_job_failed gauge
gitlab_job_failed{resource="${RESOURCE}"} 1
PROM

  stopbackup

  exit 1
}

stopbackup

# Push finish of snapshot to pushgateway
cat <<PROM | pushgateway
# HELP gitlab_job_success_timestamp_seconds The time the job succeeded.
# TYPE gitlab_job_success_timestamp_seconds gauge
gitlab_job_success_timestamp_seconds{resource="${RESOURCE}"} $(date +%s)
PROM
