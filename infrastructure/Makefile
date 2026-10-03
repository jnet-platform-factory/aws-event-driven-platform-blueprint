# infrastructure — __TENANT__'s Terragrunt foundation
#
#   make check                 fmt and validate every module, hcl fmt the live tree (no AWS)
#   make plan  ENV=dev         terragrunt plan for every unit of one environment
#   make apply ENV=dev         terragrunt apply for every unit of one environment
#   make state-bucket ENV=dev  create the environment's state bucket, once, by hand
#
# CI runs plan and apply in .github/workflows/infrastructure.yml, in the GitHub
# environment of the same name, with the bootstrap's platform-deploy-role. By
# hand, root.hcl uses the environment's AWS profile unless credentials are
# already exported (aws-vault exec ... -- make plan ENV=dev).

SHELL := /bin/bash

ENVS := dev production
ENV  ?=

TG := terragrunt run --all --non-interactive --working-dir live/$(ENV)

.DEFAULT_GOAL := help
.PHONY: help check ready plan apply state-bucket _env

help: ## Show this help
	@echo "Usage: make <target> ENV=<env>    environments: $(ENVS)"
	@echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

check: ## fmt and validate every module, hcl fmt the live tree (no AWS)
	@../scripts/validate-terraform.sh

ready: ## Fail while this component still has placeholders (no AWS)
	@../bin/ready .

plan: _env ready ## Plan every unit of ENV; changes nothing
	@$(TG) plan

# run --all apply adds -auto-approve: read the plan first. CI's approval is the
# environment's required reviewers.
apply: _env ready ## Apply every unit of ENV
	@$(TG) apply

# The state bucket must exist before the first plan. Never in CI: the deploy
# roles are denied the bucket's policy and versioning on purpose.
state-bucket: _env ready ## Create ENV's state bucket (versioned, encrypted, private), once
	@[ -z "$(CI)" ] || { echo "the state bucket is created by a human, never CI"; exit 1; }
	@terragrunt init --backend-bootstrap --non-interactive --working-dir live/$(ENV)/__PRIMARY_REGION__/vpc

_env:
	@case " $(ENVS) " in *" $(ENV) "*) ;; \
	  *) echo "ENV must be one of: $(ENVS)"; exit 1 ;; esac
