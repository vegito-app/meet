VEGITO_PROJECT_NAME := vegito-docker
GIT_HEAD_VERSION ?= $(shell git describe --tags --abbrev=7 --match "v*" 2>/dev/null)

ifdef VERSION
VEGITO_DOCKER_VERSION := $(VERSION)
endif

VEGITO_DOCKER_VERSION ?= $(GIT_HEAD_VERSION)

ifeq ($(VEGITO_DOCKER_VERSION),)
VEGITO_DOCKER_VERSION := latest
endif

VERSION ?= $(VEGITO_DOCKER_VERSION)

DOCKER_COMPOSE = docker compose 

-include jitsi.mk

server-build: jitsi-server-build
.PHONY: server-build

server-up: jitsi-server-up
.PHONY: server-up

server-logs: jitsi-server-logs
.PHONY: server-logs

server-down: jitsi-server-down
.PHONY: server-down

server-shell: jitsi-server-shell
.PHONY: server-shell
