#!/bin/bash

set -euo pipefail

source ${HOME}/.bashrc.d/200-jitsi.sh

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

cd "${JITSI_WORKTREE:-${HOME}/docker-jitsi-meet}"

# Forward Docker DIND Rootless socket
socat TCP-LISTEN:2376,fork UNIX-CONNECT:/run/user/1000/docker/docker.sock > /tmp/socat-docker-2376.log 2>&1 &
bg_pids+=("$!")

docker_compose="docker compose \
 -f docker-compose.yml \
 -f ../oidc/docker-compose.yml"

echo "🧹 Removing previous inner Jitsi stack if present..."
${docker_compose} down --remove-orphans || true

echo "🚀 Starting inner docker-jitsi-meet stack..."
${docker_compose} up -d

# Wait until all inner containers are running and healthy (when a healthcheck exists)
echo "🔎 Waiting for inner Jitsi containers to become healthy..."

START_TIME=$(date +%s)
TIMEOUT_SECONDS=$((5 * 60))

while true; do
  unhealthy="$(docker ps -a --filter label=com.docker.compose.project=docker-jitsi-meet \
    --format '{{.Names}} {{.State}} {{.Status}}' | \
    awk '
      /Exited|Dead|Restarting/ { print; bad=1 }
      /\(health: starting\)/ { bad=1 }
      /\(unhealthy\)/ { print; bad=1 }
      END { if (bad) exit 1 }
    ' || true)"

  if [ -z "$unhealthy" ]; then
    break
  fi

  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))

  if [ "$ELAPSED" -ge "$TIMEOUT_SECONDS" ]; then
    echo "❌ Timeout waiting for inner Jitsi containers after ${TIMEOUT_SECONDS}s"
    echo "$unhealthy"
    docker ps -a
    exit 1
  fi

  echo "$unhealthy"
  sleep 2
done

# The inner docker-jitsi-meet stack manages Prosody credentials itself.
# Service passwords are generated once by ./gen-passwords.sh during
# container-install.sh and persisted inside the mounted CONFIG directory.
# Rewriting them here would desynchronize the persisted accounts.

echo "🌐 Waiting for Jitsi web endpoint..."
until curl -kfsS "https://127.0.0.1:${HTTPS_PORT:-8443}" >/dev/null 2>&1; do
  sleep 2
done

jitsi_web_nginx_custom_config_dir="${JITSI_CONFIG_DIR}/web/nginx-custom"
mkdir -p ${jitsi_web_nginx_custom_config_dir}

jitsi_oidc_config=${jitsi_web_nginx_custom_config_dir}/oidc.conf

if ! grep -q "location ^~ /jitsi-openid/" \
    "${jitsi_oidc_config}" 2>/dev/null; then

cat <<'EOF' > "${jitsi_oidc_config}"
# OIDC configuration for Jitsi Meet.
location ^~ /jitsi-openid/ {
    proxy_pass http://jitsi-openid:3001/;

    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
EOF

fi

${docker_compose} exec web nginx -t
${docker_compose} exec web nginx -s reload

echo "🌐 Waiting for Jitsi web OIDC endpoint..."
until curl -kfsS "https://127.0.0.1:${HTTPS_PORT:-8443}" >/dev/null 2>&1; do
  sleep 2
done

status="$(
curl \
    -ks \
    -o /dev/null \
    -w '%{http_code}' \
    "https://127.0.0.1:${HTTPS_PORT:-8443}/jitsi-openid/authenticate?state=%7B%7D&room=test"
)"

test "$status" = "302"

echo "{\"status\":\"ready\",\"ts\":$(date +%s)}" > "${READY_FILE}"

echo "✅ Jitsi server started successfully."
sleep infinity