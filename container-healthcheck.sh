#!/bin/sh
set -e

test -f /tmp/.dockerd-ready

test -f /tmp/.jitsi-server-ready

exit 0