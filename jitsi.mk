export JITSI_DIR ?= $(CURDIR)

DOCKER_COMPOSE = docker compose

jitsi-server-build-image:
	@echo "🏗️ Building Jitsi server image..."
	@$(DOCKER_COMPOSE) build jitsi
.PHONY: jitsi-server-build-image

jitsi-server-push-image:
	@echo "📤 Pushing Jitsi server image"
	@$(DOCKER_COMPOSE) push jitsi
.PHONY: jitsi-server-push-image

jitsi-server-logs:
	@echo "📜 Viewing Jitsi server logs"
	@$(DOCKER_COMPOSE) logs -f jitsi
.PHONY: jitsi-server-logs

jitsi-server-down:
	@echo "🛑 Stopping Jitsi server container..."
	@$(DOCKER_COMPOSE) down jitsi
.PHONY: jitsi-server-down

jitsi-server-shell:
	@echo "🐳 Entering Jitsi server container shell"
	@$(DOCKER_COMPOSE) exec -it jitsi bash
.PHONY: jitsi-server-shell

jitsi-server-container-up:
	@echo "🚀 Starting Jitsi server container..."
	@$(JITSI_DIR)/docker-compose-up.sh
.PHONY: jitsi-server-container-up

jitsi-server-container-rm:
	@echo "🗑️ Removing Jitsi server container"
	@docker rm -f jitsi 2>/dev/null || true
.PHONY: jitsi-server-container-rm

jitsi-server-cert-install:
	@echo "📜 Installing SSL certificate for meet"
	@sudo certbot certonly \
	  --manual \
	  --preferred-challenges dns \
	  -d meet.vegito.app
.PHONY: jitsi-server-cert-install	

jitsi-server-cert-renew:
	@echo "📜 Renewing SSL certificate for meet"
	@sudo certbot renew
.PHONY: jitsi-server-cert-renew

jitsi-server-cache-clean:
	@echo "🧹 Cleaning Jitsi caches..."
	@docker volume rm -f jitsi_jitsi-cache 2>/dev/null || true
.PHONY: jitsi-server-cache-clean
