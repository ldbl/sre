SHELL := /bin/bash

BIN_DIR := $(CURDIR)/bin
export PATH := $(BIN_DIR):$(PATH)

# Pinned toolchain versions (mirrored by scripts/bootstrap.sh)
TERRAFORM_VERSION := 1.13.3
KUBECTL_VERSION := 1.34.1
KIND_VERSION := 0.30.0
FLUX_VERSION := 2.7.0

.PHONY: help versions plan install-hooks pre-commit fmt validate course-site-sync course-site-build course-site-serve

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

install-hooks: ## Install pre-commit hooks
	pre-commit install
	pre-commit install --hook-type prepare-commit-msg
	pre-commit install --hook-type pre-push

pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files

fmt: ## Format Terraform files
	terraform fmt -recursive infra/terraform/

validate: ## Validate Terraform configs
	cd infra/terraform/hcloud_cluster && terraform validate

course-site-sync: ## Sync docs/course markdown into Hugo content
	@./scripts/sync-course-to-hugo.sh

course-site-build: course-site-sync ## Build Hugo course site into site/public
	@command -v hugo >/dev/null || (echo "[course-site-build] hugo not found"; exit 1)
	@hugo --source site --minify

course-site-serve: course-site-sync ## Run local Hugo dev server
	@command -v hugo >/dev/null || (echo "[course-site-serve] hugo not found"; exit 1)
	@hugo server --source site -D
