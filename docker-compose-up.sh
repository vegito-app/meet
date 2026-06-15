#!/bin/bash

set -euo pipefail

bg_pids=()

kill_jobs() {
  echo "Killing background jobs"
  for pid in "${bg_pids[@]}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}

trap kill_jobs EXIT

docker_compose=${LOCAL_DOCKER_COMPOSE:-docker compose -f ${JITSI_DIR:-${PWD}}/docker-compose.yml}

${docker_compose} up jitsi
