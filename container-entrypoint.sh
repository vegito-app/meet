#!/bin/bash

set -euo pipefail

debian-entrypoint.sh echo "[entrypoint] Debian - Setup done"

debian-docker-entrypoint.sh echo "🐳 Debian Rootless Docker - Setup done"

if [ "${LOCAL_JITSI_CONTAINER_INSTALL:-true}" = "true" ]; then
    jitsi-container-install.sh
fi


exec "$@"