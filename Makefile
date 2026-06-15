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

server-up:
	@$(DOCKER_COMPOSE) up -d jitsi
.PHONY: server-up

server-logs:
	@$(DOCKER_COMPOSE) logs -f jitsi
.PHONY: server-logs

server-down:
	@$(DOCKER_COMPOSE) down
.PHONY: server-down

server-shell:
	@$(DOCKER_COMPOSE) exec jitsi bash
.PHONY: server-shell
