#!/bin/sh
set -e

test -f /tmp/.dockerd-rootless-ready

test -f /tmp/.jitsi-server-ready

exit 0