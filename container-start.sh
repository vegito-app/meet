#!/bin/bash

set -euo pipefail

READY_FILE=/tmp/.jitsi-server-ready
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

echo "📹 Starting Jitsi server..."

debian-dind-start.sh &
bg_pids+=("$!")

echo "🐳 Waiting for rootless Docker..."
until docker info >/dev/null 2>&1; do
  sleep 1
done

echo "✅ Rootless Docker is ready."

cd "${LOCAL_DOCKER_JITSI_DIR:-${HOME}/docker-jitsi-meet}"

# Forward Docker DIND Rootless socket
socat TCP-LISTEN:2376,fork UNIX-CONNECT:/run/user/1000/docker/docker.sock > /tmp/socat-docker-2376.log 2>&1 &
bg_pids+=("$!")

echo "🧹 Removing previous inner Jitsi stack if present..."
docker compose down --remove-orphans || true

echo "🚀 Starting inner docker-jitsi-meet stack..."
docker compose up -d

# The inner docker-jitsi-meet stack manages Prosody credentials itself.
# Service passwords are generated once by ./gen-passwords.sh during
# container-install.sh and persisted inside the mounted CONFIG directory.
# Rewriting them here would desynchronize the persisted accounts.

echo "🌐 Waiting for Jitsi web endpoint..."
until curl -kfsS "https://127.0.0.1:${HTTPS_PORT:-8443}" >/dev/null 2>&1; do
  sleep 2
done

echo "{\"status\":\"ready\",\"ts\":$(date +%s)}" > "${READY_FILE}"

echo "✅ Jitsi server started successfully."
sleep infinity