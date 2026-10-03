# ssm-parameters — __TENANT__'s declared SSM parameters
#
#   make check                 validate the manifest (no AWS, no values)
#   make plan  ENV=dev         what would be created or updated; writes nothing
#   make apply ENV=dev         write the changes
#
# CI runs these in .github/workflows/ssm-parameters.yml, in the GitHub
# environment of the same name, with the bootstrap's platform-deploy-role. By
# hand, they run under aws-vault with the environment's profile; values named by
# source_env must be exported first.

SHELL := /bin/bash

ENVS := dev production
ENV  ?=

PROFILE_dev        := __DEV_PROFILE__
PROFILE_production := __PRODUCTION_PROFILE__
REGION             := __PRIMARY_REGION__

PROFILE := $(if $(CI),,$(PROFILE_$(ENV)))
VAULT   := $(if $(PROFILE),aws-vault exec $(PROFILE) --,)
RUN     := $(VAULT) bin/ssm-put-parameters --environment $(ENV) --region $(REGION)

.DEFAULT_GOAL := help
.PHONY: help check ready plan apply _env

help: ## Show this help
	@echo "Usage: make <target> ENV=<env>    environments: $(ENVS)"
	@echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-9s %s\n", $$1, $$2}'

check: ## Validate the manifest (no AWS, no values)
	@for e in $(ENVS); do bin/ssm-put-parameters --environment $$e --check || exit 1; done

ready: ## Fail while this component still has placeholders (no AWS)
	@../bin/ready .

plan: _env ready ## Report CREATE / UPDATE / NO CHANGE / TYPE DRIFT per parameter; writes nothing
	@$(RUN) --dry-run

apply: _env ready ## Write every CREATE and UPDATE
	@$(RUN)

_env:
	@case " $(ENVS) " in *" $(ENV) "*) ;; \
	  *) echo "ENV must be one of: $(ENVS)"; exit 1 ;; esac
