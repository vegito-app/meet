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

local_container_cache=${CONTAINER_CACHE:-${HOME}/.container/jitsi}

local_docker_jitsi_meet_dir=${LOCAL_DOCKER_JITSI_DIR:-${local_container_cache}/docker-jitsi-meet}

mkdir -p "${local_container_cache}"

echo "📦 Jitsi cache directory: ${local_container_cache}"

jitsi_config_dir=${local_container_cache}/.jitsi-meet-cfg
jitsi_domain=${JITSI_DOMAIN:-meet.vegito.app}

echo "📁 Jitsi config directory: ${jitsi_config_dir}"
echo "🌐 Jitsi domain: ${jitsi_domain}"

mkdir -p "${local_container_cache}/.docker"
mkdir -p "${local_container_cache}/dockerd"
mkdir -p "${local_container_cache}/jitsi"

mkdir -p "${HOME}/.local/share"

echo "🐳 Configuring Docker cache..."

rm -rf "${HOME}/.local/share/docker"
ln -sfn "${local_container_cache}/dockerd" "${HOME}/.local/share/docker"

echo "📜 Persisting shell history..."

bash_history_path=${HOME}/.bash_history
rm -f "${bash_history_path}"
ln -sfn "${local_container_cache}/.bash_history" "${bash_history_path}"

echo "🎥 Configuring persistent Jitsi state..."

mkdir -p "${local_container_cache}/.jitsi-meet-cfg"

rm -rf "${local_docker_jitsi_meet_dir}"
ln -sfn \
  "${local_container_cache}/jitsi" \
  "${local_docker_jitsi_meet_dir}"

rm -rf "${HOME}/.jitsi-meet-cfg"
ln -sfn \
  "${local_container_cache}/.jitsi-meet-cfg" \
  "${HOME}/.jitsi-meet-cfg"

cert_dir="/etc/letsencrypt/live/${jitsi_domain}"
jitsi_cert_dir="${HOME}/.jitsi-meet-cfg/web/keys"

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
export CONTAINER_CACHE=${local_container_cache}
export DOCKER_CONFIG=\${CONTAINER_CACHE}/.docker
export LOCAL_DOCKER_JITSI_DIR=${local_docker_jitsi_meet_dir}
export JITSI_DOMAIN=${jitsi_domain}
EOF

if [ ! -d "${local_container_cache}/jitsi/.git" ]; then
  rm -rf "${local_container_cache}/jitsi"
  echo "⬇️ Cloning docker-jitsi-meet..."
  git clone https://github.com/jitsi/docker-jitsi-meet.git "${local_container_cache}/jitsi"
fi

cd "${local_docker_jitsi_meet_dir}"

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
  if grep -qE "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${value}|" .env
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