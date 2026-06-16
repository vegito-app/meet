#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="jitsi-server"

JITSI_HTTP_PORT=${JITSI_HTTP_PORT:-8000}
JITSI_HTTPS_PORT=${JITSI_HTTPS_PORT:-8443}
JITSI_JVB_PORT=${JITSI_JVB_PORT:-10000}

PORTS_TO_WAIT_FOR=(
  "${JITSI_HTTP_PORT}"
  "${JITSI_HTTPS_PORT}"
)

pids=()
compose_pid=
wait_pid=

kill_jobs() {
  echo "🧹 Cleaning up background jobs..."
  if [[ -n "${wait_pid:-}" ]]; then
    kill "${wait_pid}" 2>/dev/null || true
    wait "${wait_pid}" 2>/dev/null || true
  fi
}
trap kill_jobs EXIT

echo "📹 Launching Jitsi compose in background..."

docker_compose=${LOCAL_DOCKER_COMPOSE:-docker compose -f ${JITSI_DIR}/docker-compose.yml}

${docker_compose} up jitsi 2>&1 &
compose_pid=$!

{
  for port in "${PORTS_TO_WAIT_FOR[@]}"; do
    until nc -z "${CONTAINER_NAME}" "${port}"; do
      echo "⏳ Waiting for ${CONTAINER_NAME} on TCP port ${port}..."
      sleep 1
    done
  done
  echo "✅ ${CONTAINER_NAME} is reachable on HTTP/HTTPS ports."
  echo "ℹ️ UDP ${JITSI_JVB_PORT} is exposed for WebRTC media but cannot be checked with nc -z TCP."
} &
wait_pid=$!

set +e
exit_code=0
while :; do
  if ! kill -0 "${compose_pid}" 2>/dev/null; then
    echo "❌ Compose process exited prematurely!"
    exit_code=1
    break
  fi
  if ! kill -0 "${wait_pid}" 2>/dev/null; then
    echo "🥳 Jitsi server ports are ready!"
    exit_code=0
    break
  fi
  sleep 1
done

exit "${exit_code}"
