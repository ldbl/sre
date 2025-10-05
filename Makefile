SHELL := /bin/bash

BIN_DIR := $(CURDIR)/bin
export PATH := $(BIN_DIR):$(PATH)

# Pinned toolchain versions (mirrored by scripts/bootstrap.sh)
TERRAFORM_VERSION := 1.13.3
KUBECTL_VERSION := 1.34.1
KIND_VERSION := 0.30.0
FLUX_VERSION := 2.7.0

.PHONY: help versions fmt test plan backend-image backend-publish

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

versions: ## Show pinned CLI versions
	@echo "terraform\t$(TERRAFORM_VERSION)"
	@echo "kubectl\t$(KUBECTL_VERSION)"
	@echo "kind\t$(KIND_VERSION)"
	@echo "flux\t$(FLUX_VERSION)"

fmt: ## Format backend Go code and (when available) frontend Vue sources
	@if command -v go >/dev/null 2>&1; then \
		echo "[fmt] Running gofmt"; \
		gofmt -w $$(find src/backend -name '*.go'); \
	else \
		echo "[fmt] go not available; install Go to format backend"; \
	fi
	@if command -v npm >/dev/null 2>&1 && [ -f src/frontend/package.json ]; then \
		echo "[fmt] Running npm run lint"; \
		npm --prefix src/frontend run lint; \
	else \
		echo "[fmt] Vue project not bootstrapped; skipping frontend lint"; \
	fi

test: ## Execute backend unit tests and (when available) frontend tests
	@if command -v go >/dev/null 2>&1; then \
		echo "[test] Running go test"; \
		mkdir -p $(CURDIR)/.gocache; \
		cd src/backend && GOCACHE=$(CURDIR)/.gocache go test ./...; \
	else \
		echo "[test] go not available; install Go to run backend tests"; \
	fi
	@if command -v npm >/dev/null 2>&1 && [ -f src/frontend/package.json ]; then \
		echo "[test] Running npm test"; \
		npm --prefix src/frontend test; \
	else \
		echo "[test] Vue project not bootstrapped; skipping frontend tests"; \
	fi

plan: ## Run Terraform plans for all configured workspaces (pending implementation)
	@if [ -x "$(BIN_DIR)/terraform" ]; then \
		echo "[plan] Running terraform plan (stub)"; \
		"$(BIN_DIR)/terraform" version >/dev/null; \
	else \
		echo "[plan] terraform not available; run make bootstrap"; \
	fi

backend-image: ## Build backend Docker image (defaults to GHCR tag)
	@$(MAKE) -C src/backend image

backend-publish: ## Build and push backend Docker image to GHCR
	@$(MAKE) -C src/backend publish
