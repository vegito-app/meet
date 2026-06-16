#!/bin/bash

set -euo pipefail

READY_FILE=/tmp/.jitsi-server-runtime-ready
rm -f "${READY_FILE}"

bg_pids=()

kill_jobs() {
  echo "🧼 Cleaning up Jitsi services..."
  for pid in "${bg_pids[@]}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}

trap kill_jobs EXIT

echo "📹 Starting Jitsi runtime..."

debian-dind-rootless-start.sh &
bg_pids+=("$!")

echo "🐳 Waiting for rootless Docker..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

echo "✅ Rootless Docker is ready."

cd "${LOCAL_JITSI_DIR:-${HOME}/docker-jitsi-meet}"

echo "🧹 Removing previous inner Jitsi stack if present..."
docker compose down --remove-orphans || true

echo "🚀 Starting inner docker-jitsi-meet stack..."
docker compose up -d

echo "🌐 Waiting for Jitsi web endpoint..."
until curl -kfsS "https://127.0.0.1:${HTTPS_PORT:-8443}" >/dev/null 2>&1; do
  sleep 2
done

echo "{\"status\":\"ready\",\"ts\":$(date +%s)}" > "${READY_FILE}"

echo "✅ Jitsi runtime started successfully."
sleep infinity