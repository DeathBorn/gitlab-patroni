#!/bin/bash

exec &> >(tee -a "/var/log/gitlab/postgresql/gcs-snapshot-$(date +%Y%m%d-%H%M%S).log")

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
  exit 1
}

echo "SELECT pg_stop_backup(FALSE, FALSE);" > /tmp/snapshot-stop-backup

id="gcs-snapshot-$(date +%Y%m%d-%H%M)"
curl -X POST http://localhost:9091/metrics/job/gcs-snapshot/id/${id}/status/1
