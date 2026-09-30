SHELL := /bin/bash

BIN_DIR := $(CURDIR)/bin
export PATH := $(BIN_DIR):$(PATH)

# Pinned toolchain versions (minimums are checked by scripts/check-tools.sh)
TERRAFORM_VERSION := 1.16.4
KUBECTL_VERSION := 1.36.5
KIND_VERSION := 0.33.0
FLUX_VERSION := 2.9.5

.PHONY: help check-tools versions tf install-hooks pre-commit fmt validate smoke-test \
	kind-plan kind-apply kind-drift kind-destroy \
	hcloud-plan hcloud-apply hcloud-drift hcloud-destroy \
	terraform-hcloud-init terraform-hcloud-plan terraform-hcloud-apply terraform-hcloud-destroy

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

check-tools: ## Verify the workstation has every tool the labs need (lab setup)
	@./scripts/check-tools.sh

versions: ## Show pinned CLI versions
	@echo "terraform\t$(TERRAFORM_VERSION)"
	@echo "kubectl\t$(KUBECTL_VERSION)"
	@echo "kind\t$(KIND_VERSION)"
	@echo "flux\t$(FLUX_VERSION)"

# --- Terraform -------------------------------------------------------------
# plan -> read -> apply exactly that plan, while it is fresh (Chapter 02):
# *-plan saves the plan with scripts/guard-terraform-plan.sh, *-apply applies
# only that saved plan and refuses one older than TF_MAX_AGE minutes.
KIND_DIR   := infra/terraform/kind_cluster
HCLOUD_DIR := infra/terraform/hcloud_cluster
TF_MAX_AGE ?= 60
GUARD_TF   := scripts/guard-terraform-plan.sh

tf: ## List the Terraform modules and how to run them
	@echo "Terraform modules (plan -> read -> apply that plan, within $(TF_MAX_AGE) min):"
	@echo "  kind    $(KIND_DIR)    local kind cluster        make kind-plan | kind-apply | kind-drift | kind-destroy"
	@echo "  hcloud  $(HCLOUD_DIR)  Hetzner cluster (Cloud)   make hcloud-plan | hcloud-apply | hcloud-drift | hcloud-destroy"
	@echo "                                                     (needs the TF_VAR_* from load-env.sh; normally CI applies it)"
	@echo "  lab     infra/terraform/state-lab        Chapter 02 state lab      run by hand, as the lab says"
	@echo "Check without credentials: make validate"

kind-plan: ## kind: plan and save it (read it before kind-apply)
	@$(GUARD_TF) plan --dir $(KIND_DIR) --out tfplan
	@terraform -chdir=$(KIND_DIR) show -no-color tfplan | grep -E '^Plan:|^No changes' || true

kind-apply: ## kind: apply exactly the saved plan (refused when older than TF_MAX_AGE min)
	@$(GUARD_TF) apply --dir $(KIND_DIR) --out tfplan --max-age-minutes $(TF_MAX_AGE)

kind-drift: ## kind: does the cluster match the code? (0 = yes, 2 = drift, 1 = error)
	@terraform -chdir=$(KIND_DIR) init -input=false >/dev/null
	@rc=0; terraform -chdir=$(KIND_DIR) plan -input=false -lock=false -detailed-exitcode >/dev/null || rc=$$?; \
	case $$rc in 0) echo "[drift] kind: no changes - code, state and cluster match";; \
	  2) echo "[drift] kind: something would change - run make kind-plan and read it";; \
	  *) echo "[drift] kind: plan failed (exit $$rc)";; esac; exit $$rc

kind-destroy: ## kind: delete the local cluster and empty its state
	@$(MAKE) --no-print-directory -C $(KIND_DIR) destroy

hcloud-plan: terraform-hcloud-plan ## Hetzner: plan and save it (read it before hcloud-apply)
hcloud-apply: terraform-hcloud-apply ## Hetzner: apply exactly the saved plan (costs money - destroy after)
hcloud-destroy: terraform-hcloud-destroy ## Hetzner: pre-destroy cleanup, destroy, check nothing is left

hcloud-drift: ## Hetzner: does the cloud match the code? (0 = yes, 2 = drift, 1 = error)
	@$(MAKE) --no-print-directory -C $(HCLOUD_DIR) init >/dev/null
	@rc=0; terraform -chdir=$(HCLOUD_DIR) plan -input=false -lock=false -detailed-exitcode >/dev/null || rc=$$?; \
	case $$rc in 0) echo "[drift] hcloud: no changes";; \
	  2) echo "[drift] hcloud: something would change - run make hcloud-plan and read it";; \
	  *) echo "[drift] hcloud: plan failed (exit $$rc)";; esac; exit $$rc

install-hooks: ## Install pre-commit hooks
	pre-commit install
	pre-commit install --hook-type prepare-commit-msg
	pre-commit install --hook-type pre-push

pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files

fmt: ## Format Terraform files
	terraform fmt -recursive infra/terraform/

smoke-test: ## Run infrastructure smoke tests against the cluster
	bash tests/smoke-test.sh

validate: ## Validate every Terraform module (no backend, no credentials)
	@# A throw-away data dir per module: a .terraform left by a real init would make even
	@# -backend=false read the real state (with whatever credentials the shell has).
	@for d in $(KIND_DIR) $(HCLOUD_DIR) infra/terraform/state-lab; do \
	  echo "==> $$d"; \
	  data=$$(mktemp -d); \
	  TF_DATA_DIR=$$data terraform -chdir=$$d init -input=false -backend=false >/dev/null && \
	  TF_DATA_DIR=$$data terraform -chdir=$$d validate; rc=$$?; rm -rf "$$data"; \
	  [ $$rc -eq 0 ] || exit $$rc; \
	done

terraform-hcloud-init: ## Terraform init for Hetzner cluster
	@$(MAKE) -C infra/terraform/hcloud_cluster init

terraform-hcloud-plan: ## Terraform plan for Hetzner cluster, saved (same as hcloud-plan)
	@$(MAKE) --no-print-directory -C $(HCLOUD_DIR) init
	@$(GUARD_TF) plan --dir $(HCLOUD_DIR) --out tfplan
	@terraform -chdir=$(HCLOUD_DIR) show -no-color tfplan | grep -E '^Plan:|^No changes' || true

terraform-hcloud-apply: ## Terraform apply of the saved Hetzner plan (same as hcloud-apply)
	@$(GUARD_TF) apply --dir $(HCLOUD_DIR) --out tfplan --max-age-minutes $(TF_MAX_AGE)

terraform-hcloud-destroy: ## Terraform destroy for Hetzner cluster (with state cleanup)
	@$(MAKE) -C infra/terraform/hcloud_cluster init
	@$(MAKE) -C infra/terraform/hcloud_cluster destroy
