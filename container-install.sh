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

local_container_cache=${CONTAINER_CACHE:-${HOME}/.cache/jitsi}
jitsi_dir=${LOCAL_JITSI_DIR:-${HOME}/docker-jitsi-meet}
jitsi_config_dir=${JITSI_CONFIG_DIR:-${HOME}/.jitsi-meet-cfg}
jitsi_domain=${JITSI_DOMAIN:-meet.vegito.app}

mkdir -p "${local_container_cache}"
echo "📦 Jitsi cache directory: ${local_container_cache}"
echo "📁 Jitsi config directory: ${jitsi_config_dir}"
echo "🌐 Jitsi domain: ${jitsi_domain}"
mkdir -p "${local_container_cache}/dockerd"
mkdir -p "${HOME}/.local/share"

echo "🐳 Configuring Docker cache..."
rm -rf "${HOME}/.local/share/docker"
ln -sfn "${local_container_cache}/dockerd" "${HOME}/.local/share/docker"

bash_history_path=${HOME}/.bash_history
echo "📜 Persisting shell history..."
rm -f "${bash_history_path}"
ln -sfn "${local_container_cache}/.bash_history" "${bash_history_path}"

echo "🎥 Configuring persistent Jitsi state..."
mkdir -p "${local_container_cache}/.jitsi-meet-cfg"

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
cat <<EOF > "${HOME}/.bashrc.d/.bashrc"
export HISTSIZE=50000
export HISTFILESIZE=100000
export DOCKER_HOST=unix:///run/user/${LOCAL_USER_ID:-1000}/docker.sock
export DOCKER_CONFIG=${local_container_cache}/.docker
export DOCKER_BUILDKIT=1
export LOCAL_JITSI_DIR=${jitsi_dir}
export CONTAINER_CACHE=${local_container_cache}
export JITSI_DOMAIN=${jitsi_domain}
EOF

git_config_global=${HOME}/.gitconfig
if [ -f "${git_config_global}" ]; then
  mkdir -p "${local_container_cache}/git"
  rsync -a "${git_config_global}" "${local_container_cache}/git/"
  rm -f "${git_config_global}"
  ln -sfn "${local_container_cache}/git/.gitconfig" "${git_config_global}"
fi

if [ ! -d "${jitsi_dir}/.git" ]; then
  rm -rf "${jitsi_dir}"
  echo "⬇️ Cloning docker-jitsi-meet..."
  git clone https://github.com/jitsi/docker-jitsi-meet.git "${jitsi_dir}"
fi

cd "${jitsi_dir}"

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
fi

echo "✅ Jitsi initialization completed"
caches_refresh_success=true