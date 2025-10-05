SHELL := /bin/bash

BIN_DIR := $(CURDIR)/bin
export PATH := $(BIN_DIR):$(PATH)

# Pinned toolchain versions (mirrored by scripts/bootstrap.sh)
TERRAFORM_VERSION := 1.13.3
KUBECTL_VERSION := 1.34.1
KIND_VERSION := 0.30.0
FLUX_VERSION := 2.7.0

.PHONY: help versions plan

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

versions: ## Show pinned CLI versions
	@echo "terraform\t$(TERRAFORM_VERSION)"
	@echo "kubectl\t$(KUBECTL_VERSION)"
	@echo "kind\t$(KIND_VERSION)"
	@echo "flux\t$(FLUX_VERSION)"

plan: ## Run Terraform plans for all configured workspaces (pending implementation)
	@if [ -x "$(BIN_DIR)/terraform" ]; then \
		echo "[plan] Running terraform plan (stub)"; \
		"$(BIN_DIR)/terraform" version >/dev/null; \
	else \
		echo "[plan] terraform not available; run make bootstrap"; \
	fi
