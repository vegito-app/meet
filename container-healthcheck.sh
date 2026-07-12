#!/bin/sh
set -eu

test -f /tmp/.dockerd-ready

test -f /tmp/.jitsi-server-ready

DOCKER_HOST=${DOCKER_HOST:-unix:///run/user/1000/docker.sock}
export DOCKER_HOST

# Fail if any inner compose container is restarting, exited, dead or unhealthy.
docker ps -a \
  --filter label=com.docker.compose.project=docker-jitsi-meet \
  --format '{{.State}} {{.Status}}' |
awk '
  /Exited|Dead|Restarting/ { exit 1 }
  /\(unhealthy\)/ { exit 1 }
'

exit 0