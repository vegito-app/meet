# Vegito Jitsi Server

Portable Jitsi server packaged as a single Docker container using Docker-in-Docker (DIND) and Rootless Docker.

This project encapsulates a full `docker-jitsi-meet` deployment inside an isolated container while keeping persistent state and reproducible deployments.

## Features

- 🚀 Single container deployment
- 🐳 Docker-in-Docker (DIND)
- 🔒 Rootless Docker
- 📦 Persistent cache
- 📜 Persistent shell history
- 🎥 Persistent Jitsi configuration
- 🔐 Let's Encrypt certificate integration
- 📌 Pinned Jitsi commit or release tag
- ♻️ Factory reset support
- 🧹 Cache cleanup support
- 🔁 Fully reproducible deployments
- 🧪 Isolated from the host Docker installation

## Architecture

```text
Host Docker
└── jitsi-server container
    └── Rootless Docker daemon
        └── docker-jitsi-meet
            ├── web
            ├── prosody
            ├── jicofo
            └── jvb
```

## Why DIND?

The goal of this project is not merely to run Jitsi.

The objective is to package an entire Jitsi infrastructure into a portable and reproducible appliance:

- no host pollution;
- isolated Docker daemon;
- deterministic upgrades;
- reproducible debugging;
- easy backup and migration.

## Repository Layout

```text
.
├── container-entrypoint.sh
├── container-install.sh
├── container-start.sh
├── container-up.sh
├── docker-compose-up.sh
├── docker-compose.yml
├── Dockerfile
├── jitsi.mk
├── LICENSE
├── Makefile
└── README.md
```

## Persistent Data

The following data are persisted:

- Jitsi cache
- Docker images and layers
- docker-jitsi-meet checkout
- generated secrets
- certificates
- shell history

Typical mount:

```text
/home/debian/.cache/jitsi
```

## Docker Volumes

This project intentionally persists its state through Docker volumes.

Example:

```text
jitsi_jitsi-cache
    -> /home/debian/.cache/jitsi
```

The cache volume contains:

- docker-jitsi-meet checkout
- inner Docker images and layers
- generated Jitsi secrets
- shell history
- persistent Docker configuration
- Rootless Docker state
- Jitsi configuration and runtime data

This design dramatically reduces startup time and allows reproducible deployments while keeping the host clean.

## Jitsi Version Pinning

The deployment intentionally pins a specific Jitsi release or commit.

Example:

```text
stable-11031
```

This avoids unexpected regressions from upstream changes.

## Environment Variables

The deployment can be customized using environment variables.

### Core variables

| Variable | Description |
|----------|-------------|
| `JITSI_DOMAIN` | Public DNS name of the Jitsi instance. Example: `meet.vegito.app`. |
| `PUBLIC_URL` | URL advertised to browsers and WebRTC clients. |
| `JITSI_COMMIT` | Git tag, branch or commit used to pin docker-jitsi-meet. |
| `HTTP_PORT` | HTTP port exposed by the web container. |
| `HTTPS_PORT` | HTTPS port exposed by the web container. |
| `TZ` | Time zone used by containers. |
| `CONTAINER_CACHE` | Root cache directory persisted inside Docker volumes. |
| `LOCAL_JITSI_DIR` | Location of the docker-jitsi-meet checkout. |
| `JITSI_CONFIG_DIR` | Location of persistent Jitsi configuration. |

### Advanced XMPP variables

| Variable | Description |
|----------|-------------|
| `XMPP_SERVER` | Hostname of the Prosody container. |
| `XMPP_BOSH_URL_BASE` | Internal BOSH endpoint used by the web frontend. |
| `XMPP_DOMAIN` | Main XMPP domain used by Jitsi. |
| `XMPP_AUTH_DOMAIN` | Authentication domain for internal components. |
| `XMPP_MUC_DOMAIN` | Multi-user chat domain. |
| `XMPP_INTERNAL_MUC_DOMAIN` | Internal MUC domain used by Jicofo. |

Example:

```env
JITSI_DOMAIN=meet.vegito.app
JITSI_COMMIT=stable-11031
HTTPS_PORT=8443
PUBLIC_URL=https://meet.vegito.app:8443
```

## Make Targets

Examples:

```bash
make server-up
make server-down
make server-logs
make server-reset
make server-cache-clean
```

Typical workflows:

Start:

```bash
make server-up
```

Inspect logs:

```bash
make server-logs
```

Factory reset:

```bash
make server-reset
```

## Networking

Jitsi typically requires:

- HTTPS: 443 (or 8443)
- Media: UDP 10000

For public deployments behind NAT:

- forward UDP 10000 to JVB;
- expose HTTPS via reverse proxy or direct access.

## Reverse Proxy

The server can be published behind:

- NGINX
- Traefik
- Caddy

Example domain:

```text
https://meet.vegito.app
```

## Debugging Story

A subtle upstream change caused XMPP BOSH requests to target:

```text
http://xmpp.meet.jitsi:5280
```

while modern Docker deployments expose:

```text
http://prosody:5280
```

The fix was:

```env
XMPP_BOSH_URL_BASE=http://prosody:5280
```

This project intentionally keeps such fixes reproducible through version pinning.

## Disclaimer

Jitsi is an amazing open-source project.

This repository provides an alternative packaging strategy focused on portability, isolation and reproducibility.

## License

See [LICENSE](LICENSE).
