#!/bin/bash
set -euo pipefail

# Set default environment variables
export PROMETHEUS_CONFIG_FILE=${PROMETHEUS_CONFIG_FILE:-/prometheus.yml}
export PROMETHEUS_DATA_DIR=${PROMETHEUS_DATA_DIR:-/data}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-}
export AWS_REGION=${AWS_REGION:-}
export AWS_BUCKET_NAME=${AWS_BUCKET_NAME:-}
export AWS_S3_ENDPOINT=${AWS_S3_ENDPOINT:-}
export BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-0 0 * * *}
export RETENTION_DAYS=${RETENTION_DAYS:-30}
export MAX_DISK_USAGE_PERCENT=${MAX_DISK_USAGE_PERCENT:-80}
export PROMSTER_LOG_LEVEL=${PROMSTER_LOG_LEVEL:-info}
export PROMSTER_SCRAPE_INTERVAL=${PROMSTER_SCRAPE_INTERVAL:-30s}
export PROMSTER_SCRAPE_TIMEOUT=${PROMSTER_SCRAPE_TIMEOUT:-30s}
export PROMSTER_EVALUATION_INTERVAL=${PROMSTER_EVALUATION_INTERVAL:-30s}
export PROMSTER_SCHEME=${PROMSTER_SCHEME:-http}
export PROMSTER_TLS_INSECURE=${PROMSTER_TLS_INSECURE:-false}
export PROMSTER_ETCD_TIMEOUT=${PROMSTER_ETCD_TIMEOUT:-30}
export PROMSTER_REGISTER_TTL=${PROMSTER_REGISTER_TTL:-60}

# 1. Validate environment
config-validator --check-env

# 2. Initialize system
config-validator --init

# 3. Check if data directory is empty or corrupted
if [ ! -d "${PROMETHEUS_DATA_DIR}" ] || [ -z "$(ls -A ${PROMETHEUS_DATA_DIR})" ] || [ -f "${PROMETHEUS_DATA_DIR}/CORRUPTED" ]; then
  echo "Data directory is empty or corrupted, triggering recovery"
  backup-manager --restore
fi

# 4. Start monitoring
(while true; do
  /opt/bitnami/prometheus/bin/prometheus --config.file=${PROMETHEUS_CONFIG_FILE} --storage.tsdb.path=${PROMETHEUS_DATA_DIR} --web.enable-lifecycle &
  prometheus_pid=$!
  wait $prometheus_pid
  echo "Prometheus crashed, restarting..."
done) &

# 5. Wait for Prometheus to be ready
while ! curl -s -f -o /dev/null http://localhost:9090/-/ready; do
   sleep 1
done

# 6. Start Promster
/bin/promster &

# 5. Start backup and storage manager
echo "${BACKUP_SCHEDULE} backup-manager --backup" >> /etc/crontab
echo "0 0 * * * storage-manager --optimize" >> /etc/crontab
supercronic /etc/crontab
