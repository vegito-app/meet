FROM dbndev/vegito-public:trixie-debian-dockerd-latest

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
ENV LOCAL_DOCKER_JITSI_DIR=${HOME}/docker-jitsi-meet
ENV CONTAINER_CACHE=${HOME}/.cache/jitsi
ENV LOCAL_JITSI_CONTAINER_INSTALL=true

WORKDIR ${HOME}

COPY container-entrypoint.sh /usr/local/bin/jitsi-container-entrypoint.sh
COPY container-install.sh /usr/local/bin/jitsi-container-install.sh
COPY container-start.sh /usr/local/bin/jitsi-container-start.sh
COPY container-healthcheck.sh /usr/local/bin/jitsi-container-healthcheck.sh

ENTRYPOINT [ "tini", "--", "jitsi-container-entrypoint.sh" ]

CMD [ "jitsi-container-start.sh" ]

HEALTHCHECK CMD /usr/local/bin/jitsi-container-healthcheck.sh

RUN mkdir -p  /home/debian/.cache/jitsi /home/debian/.local/share/docker