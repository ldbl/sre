SHELL := /bin/bash
TF    := terraform
TF_DIR := $(CURDIR)
CLUSTER_NAME := sre-control-plane

.PHONY: help init plan apply destroy destroy-force state-clean state-clean-k8s state-list kubeconfig test

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Terraform init
	$(TF) init

GUARD_TF   := ../../../scripts/guard-terraform-plan.sh
TF_MAX_AGE ?= 60

plan: ## Terraform plan, saved to tfplan (read it before apply)
	@$(GUARD_TF) plan --dir . --out tfplan

apply: ## Apply exactly the saved tfplan (refused when older than TF_MAX_AGE minutes)
	@$(GUARD_TF) apply --dir . --out tfplan --max-age-minutes $(TF_MAX_AGE)

# The state is emptied only after the cluster is proven gone: emptying it first, or after a failed
# delete, would make Terraform forget a cluster that still runs. Any failure stops here, loudly.
destroy: ## Destroy cluster: delete the kind cluster, prove it is gone, then empty the state
	@echo "==> Deleting kind cluster $(CLUSTER_NAME)..."
	@clusters="$$(kind get clusters 2>/dev/null)" || { echo "ERROR: 'kind get clusters' failed - is Docker running? Nothing was deleted."; exit 1; }; \
	if printf '%s\n' "$$clusters" | grep -qx '$(CLUSTER_NAME)'; then \
		kind delete cluster --name $(CLUSTER_NAME) || { echo "ERROR: kind delete cluster failed - the state is kept."; exit 1; }; \
	else \
		echo "    no kind cluster $(CLUSTER_NAME) - nothing to delete"; \
	fi; \
	if kind get clusters 2>/dev/null | grep -qx '$(CLUSTER_NAME)'; then \
		echo "ERROR: kind cluster $(CLUSTER_NAME) still exists - the state is kept."; exit 1; \
	fi
	@echo "==> Cleaning up Terraform state..."
	@$(MAKE) --no-print-directory state-clean
	@rm -f $(TF_DIR)/kubeconfig.yaml
	@echo "==> Done. Cluster deleted and state emptied. The lab's databases and MinIO data are gone with it; age.agekey is kept."

state-list: ## List all resources in state
	$(TF) state list

state-clean-k8s: ## Remove all kubernetes/helm resources from state
	@$(TF) state list 2>/dev/null | grep -E '^kubernetes_|^helm_' | while IFS= read -r r; do \
		echo "  removing $$r"; \
		$(TF) state rm "$$r" 2>/dev/null || true; \
	done

state-clean: ## Remove ALL resources from state (stops at the first failure)
	@if [ ! -f terraform.tfstate ]; then echo "    no state file - nothing to remove"; exit 0; fi; \
	resources="$$($(TF) state list)" || { echo "ERROR: terraform state list failed."; exit 1; }; \
	printf '%s\n' "$$resources" | sed '/^$$/d' | while IFS= read -r r; do \
		echo "  removing $$r"; \
		$(TF) state rm "$$r" >/dev/null || { echo "ERROR: could not remove $$r from the state."; exit 1; }; \
	done
	@echo "==> State is now empty."

test: ## Validate Terraform configuration
	@if [ ! -d .terraform ]; then $(TF) init -input=false -backend=false; fi
	$(TF) validate

kubeconfig: ## Export KUBECONFIG path
	@echo "export KUBECONFIG=$(TF_DIR)/kubeconfig.yaml"
