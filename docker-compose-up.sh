#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="jitsi-server"

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

set +e
{
  echo "⏱️ Waiting for Jitsi Server..."
  until $docker_compose exec -T jitsi test -f /tmp/.jitsi-server-ready; do
    echo "⏳ Waiting for jitsi-server to start..."
    sleep 1
  done
  echo "✅ service jitsi-server ready"
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
