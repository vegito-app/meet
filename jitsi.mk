export JITSI_DIR ?= $(CURDIR)

DOCKER_COMPOSE = docker compose

jitsi-server-build:
	@$(DOCKER_COMPOSE) build jitsi
.PHONY: jitsi-server-build

jitsi-server-up:
	@$(DOCKER_COMPOSE) up -d jitsi
.PHONY: jitsi-server-up

jitsi-server-logs:
	@$(DOCKER_COMPOSE) logs -f jitsi
.PHONY: jitsi-server-logs

jitsi-server-down:
	@$(DOCKER_COMPOSE) down jitsi
.PHONY: jitsi-server-down

jitsi-server-shell:
	@$(DOCKER_COMPOSE) exec jitsi bash
.PHONY: jitsi-server-shell

jitsi-server-container-up: jitsi-server-container-rm
	@echo "🚀 Starting Jitsi server container..."
	@$(JITSI_DIR)/container-up.sh
.PHONY: jitsi-server-container-up

jitsi-server-container-rm:
	@docker rm -f jitsi 2>/dev/null || true
.PHONY: jitsi-server-container-rm

jitsi-server-cert-install:
	@sudo certbot certonly \
	  --manual \
	  --preferred-challenges dns \
	  -d meet.vegito.app
.PHONY: jitsi-server-cert-install	

jitsi-server-cert-renew:
	@sudo certbot renew
.PHONY: jitsi-server-cert-renew

jitsi-server-reset:
	@$(MAKE) jitsi-server-down
	@docker volume rm -f jitsi_jitsi-cache 2>/dev/null || true
	@$(MAKE) jitsi-server-up
.PHONY: jitsi-server-reset

jitsi-server-cache-clean:
	@echo "🧹 Cleaning Jitsi caches..."
	@-docker exec jitsi-server bash -lc '\
	 rm -rf ~/.cache/jitsi ~/.cache/dockerd ~/docker-jitsi-meet ~/.jitsi-meet-cfg \
	'
.PHONY: jitsi-server-cache-clean

jitsi-server-rebuild:
	@$(MAKE) jitsi-server-container-rm
	@$(MAKE) jitsi-server-build
	@$(MAKE) jitsi-server-container-up
.PHONY: jitsi-server-rebuild
