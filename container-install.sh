#!/bin/bash

set -euo pipefail

caches_refresh_success=false

check_success() {
  if [ "${caches_refresh_success}" = true ]; then
    echo "♻️ Jitsi caches refreshed successfully."
  else
    echo "❌ Jitsi caches refresh failed."
  fi
}

trap check_success EXIT

local_container_cache=${JITSI_DATA_DIR:-${HOME}/.container/jitsi}

jitsi_worktree=${JITSI_WORKTREE:-${PWD}/.docker-jitsi-meet}

mkdir -p "${local_container_cache}"

echo "📦 Jitsi cache directory: ${local_container_cache}"

jitsi_config_dir=${JITSI_CONFIG_DIR:-${local_container_cache}/config}

jitsi_domain=${JITSI_DOMAIN:-meet.vegito.app}

echo "📁 Jitsi config directory: ${jitsi_config_dir}"
echo "🌐 Jitsi domain: ${jitsi_domain}"

mkdir -p "${local_container_cache}/.docker"
mkdir -p "${local_container_cache}/dockerd"
mkdir -p "${jitsi_worktree}"

mkdir -p "${HOME}/.local/share"

echo "🐳 Configuring Docker cache..."

rm -rf "${HOME}/.local/share/docker"
ln -sfn "${local_container_cache}/dockerd" "${HOME}/.local/share/docker"

echo "📜 Persisting shell history..."

bash_history_path=${HOME}/.bash_history
rm -f "${bash_history_path}"
ln -sfn "${local_container_cache}/.bash_history" "${bash_history_path}"

echo "🎥 Configuring persistent Jitsi state..."

mkdir -p "${local_container_cache}/config"

rm -rf "${HOME}/.jitsi-meet-cfg"
ln -sfn \
  "${jitsi_config_dir}" \
  "${HOME}/.jitsi-meet-cfg"

cert_dir="/etc/letsencrypt/live/${jitsi_domain}"
jitsi_cert_dir="${HOME}/.jitsi/web/keys"

mkdir -p "${jitsi_cert_dir}"

if sudo test -r "${cert_dir}/fullchain.pem" && \
   sudo test -r "${cert_dir}/privkey.pem"; then

  echo "🔐 Installing Let's Encrypt certificate for ${jitsi_domain}"

  sudo install -m 644 \
    "${cert_dir}/fullchain.pem" \
    "${jitsi_cert_dir}/cert.crt"

  sudo install -m 600 \
    "${cert_dir}/privkey.pem" \
    "${jitsi_cert_dir}/cert.key"

  sudo chown "${USER}:${USER}" \
    "${jitsi_cert_dir}/cert.crt" \
    "${jitsi_cert_dir}/cert.key"

else
  echo "⚠️ No Let's Encrypt certificate found for ${jitsi_domain}"
fi

mkdir -p "${HOME}/.bashrc.d"
cat <<EOF > "${HOME}/.bashrc.d/200-jitsi.sh"
export DOCKER_HOST=unix:///run/user/${LOCAL_USER_ID:-1000}/docker.sock
export JITSI_DATA_DIR=${local_container_cache}
export DOCKER_CONFIG=${JITSI_DATA_DIR}/.docker
export JITSI_WORKTREE=${jitsi_worktree}
export JITSI_DOMAIN=${jitsi_domain}
EOF

if [ ! -d "${jitsi_worktree}/.git" ]; then
  rm -rf "${jitsi_worktree}"
  echo "⬇️ Cloning docker-jitsi-meet..."
  git clone https://github.com/jitsi/docker-jitsi-meet.git "${jitsi_worktree}"
fi

cd "${jitsi_worktree}"

jitsi_commit="${JITSI_COMMIT:-}"

if [ -n "${jitsi_commit}" ]; then
  echo "📌 Checkout Jitsi commit ${jitsi_commit}"
  git fetch --all --tags --prune
  git checkout "${jitsi_commit}"
else
  echo "📌 No JITSI_COMMIT specified, keeping current checkout"
fi
if [ ! -f .env ]; then
  cp env.example .env
fi

set_env_value() {
  local key="$1"
  local value="$2"
  escaped_value=$(
    printf '%s' "$value" |
    sed 's/[&|]/\\&/g'
  )
  if grep -qE "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${escaped_value}|" .env
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> .env
  fi
}

set_env_value CONFIG "${jitsi_config_dir}"
set_env_value ENABLE_LETSENCRYPT "0"
set_env_value HTTP_PORT "${HTTP_PORT:-8000}"
set_env_value HTTPS_PORT "${HTTPS_PORT:-8443}"
set_env_value PUBLIC_URL "${PUBLIC_URL:-https://${jitsi_domain}:${HTTPS_PORT:-8443}}"
set_env_value TZ "${TZ:-Europe/Paris}"
set_env_value XMPP_DOMAIN "meet.jitsi"
set_env_value XMPP_AUTH_DOMAIN "auth.meet.jitsi"
set_env_value XMPP_MUC_DOMAIN "muc.meet.jitsi"
set_env_value XMPP_INTERNAL_MUC_DOMAIN "internal-muc.meet.jitsi"
set_env_value XMPP_SERVER "prosody"
set_env_value XMPP_BOSH_URL_BASE "http://prosody:5280"
set_env_value JICOFO_AUTH_USER "focus"
set_env_value JVB_AUTH_USER "jvb"

set_env_value JVB_PORT "${JVB_PORT:-10000}"
set_env_value ENABLE_XMPP_WEBSOCKET "1"

# -----------------------------------------------------------------------------
# OpenID Connect (Authentik) via jitsi-go-openid
# -----------------------------------------------------------------------------

jitsi_public_url="${PUBLIC_URL:-https://${jitsi_domain}:${HTTPS_PORT:-8443}}"
jitsi_jwt_app_id="${JITSI_JWT_APP_ID:-jitsi}"
jitsi_jwt_secret="${JITSI_JWT_SECRET:-$(openssl rand -hex 32)}"

# docker-jitsi-meet
set_env_value ENABLE_AUTH "1"
set_env_value ENABLE_GUESTS "1"
set_env_value AUTH_TYPE "jwt"
set_env_value JWT_APP_ID "${jitsi_jwt_app_id}"
set_env_value JWT_APP_SECRET "${jitsi_jwt_secret}"
set_env_value JWT_ACCEPTED_ISSUERS "jitsi"
set_env_value JWT_ACCEPTED_AUDIENCES "jitsi"
set_env_value TOKEN_AUTH_URL \
  "${jitsi_public_url}/jitsi-openid/authenticate?state={state}&room={room}"

# jitsi-go-openid
set_env_value JITSI_SECRET "${jitsi_jwt_secret}"
set_env_value JITSI_URL "${jitsi_public_url}"
set_env_value JITSI_SUB "${jitsi_jwt_app_id}"
set_env_value ISSUER_BASE_URL "${JITSI_OIDC_ISSUER_BASE_URL:-https://auth.vegito.app/application/o/jitsi/}"
set_env_value BASE_URL "${jitsi_public_url}/jitsi-openid"
set_env_value CLIENT_ID "${JITSI_OIDC_CLIENT_ID:-jitsi}"
set_env_value SECRET "${JITSI_OIDC_CLIENT_SECRET:-}"
set_env_value PREJOIN "false"
set_env_value DEEPLINK "true"
set_env_value NAME_KEY "name"
set_env_value JVB_ADVERTISE_IPS "${JVB_ADVERTISE_IPS}"

mkdir -p \
  "${jitsi_config_dir}/web" \
  "${jitsi_config_dir}/transcripts" \
  "${jitsi_config_dir}/prosody/config" \
  "${jitsi_config_dir}/prosody/prosody-plugins-custom" \
  "${jitsi_config_dir}/jicofo" \
  "${jitsi_config_dir}/jvb" \
  "${jitsi_config_dir}/jigasi" \
  "${jitsi_config_dir}/jibri"

if ! grep -q '^JICOFO_AUTH_PASSWORD=.' .env 2>/dev/null; then
  echo "🔑 Generating Jitsi secrets..."
  ./gen-passwords.sh
else
  echo "🔐 Reusing existing Jitsi secrets from .env"
fi

if git diff --quiet; then
  echo "📄 Git checkout is clean"
else
  echo "⚠️ Local modifications detected in docker-jitsi-meet"
fi

echo "✅ Jitsi initialization completed"
caches_refresh_success=true