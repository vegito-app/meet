FROM dbndev/vegito-public:hub-debian-golang-latest AS go-build
ARG debian_version=trixie
ARG TARGETPLATFORM

ARG uid=1000
ARG gid=1000
ARG go_pkg=/home/debian/go/pkg
ARG go_cache=/home/debian/.cache/go-build
ENV GOMODCACHE=${go_pkg}/mod
ENV GOCACHE=${go_cache}
ENV GOBIN=/home/debian/go/bin
ENV CGO_ENABLED=0
RUN --mount=type=cache,id=vegito-debian-${TARGETPLATFORM}-${debian_version}-root-go-pkg,target=${go_pkg},sharing=locked,uid=${uid},gid=${gid} \
    --mount=type=cache,id=vegito-debian-${TARGETPLATFORM}-${debian_version}-root-go-build,target=${go_cache},sharing=locked,uid=${uid},gid=${gid} \
    go install -v github.com/vegito-app/local/proxy@latest

FROM dbndev/vegito-public:trixie-debian-docker-latest

USER root

ARG non_root_user=jitsi
ARG uid=1000
ARG gid=1000

# 👤 Rename non root user
RUN usermod -l ${non_root_user} ${USER} \
    && groupmod -n ${non_root_user} ${USER} \
    && \
    echo "${non_root_user}:${non_root_user}" | chpasswd && \
    adduser ${non_root_user} sudo && \
    echo "${non_root_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${non_root_user} && \
    chmod 0440 /etc/sudoers.d/${non_root_user}


# Use Bash
RUN ln -sf /usr/bin/bash /bin/sh
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    netcat-openbsd \
    rsync \
    socat \
    unzip \
    && rm -rf /var/lib/apt/lists/*

USER ${non_root_user}

ENV USER=${non_root_user}
ENV HOME=/home/debian
ENV DOCKER_HOST=unix:///run/user/1000/docker.sock
ENV DOCKER_BUILDKIT=1
ENV LOCAL_JITSI_DIR=${HOME}/docker-jitsi-meet
ENV CONTAINER_CACHE=${HOME}/.cache/jitsi
ENV LOCAL_JITSI_CONTAINER_INSTALL=true

WORKDIR ${HOME}

COPY container-entrypoint.sh /usr/local/bin/jitsi-container-entrypoint.sh
COPY container-install.sh /usr/local/bin/jitsi-container-install.sh
COPY container-start.sh /usr/local/bin/jitsi-container-start.sh

COPY --from=go-build /home/debian/go/bin/proxy         /usr/local/bin/localproxy

ENTRYPOINT [ "tini", "--", "jitsi-container-entrypoint.sh" ]
CMD [ "jitsi-container-start.sh" ]
HEALTHCHECK CMD test -f /tmp/.jitsi-runtime-ready || exit 1

RUN mkdir -p  /home/debian/.cache/jitsi /home/debian/.local/share/docker