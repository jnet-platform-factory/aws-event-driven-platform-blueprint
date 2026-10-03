# platform-api — GET /platform/info, the SSM bridge end to end
#
#   make check                                    tests, sam validate, parameter files (no AWS)
#   make changeset STAGE=dev                      build, package and create a change set; executes nothing
#   make execute STAGE=dev CHANGE_SET=<name>      execute a change set someone has read
#   make delete-changeset STAGE=dev CHANGE_SET=<name>
#
# CI runs these in .github/workflows/platform-api.yml with the bootstrap's
# app-deploy-role, in the GitHub environment of the stage. By hand, they run
# under aws-vault.
#
# STAGE    dev or production: picks deployments/<STAGE>.json, the account and the profile
# CI=true  (set by GitHub Actions) use the ambient credentials, not aws-vault

SHELL  := /bin/bash
PYTHON ?= python3

STAGES := dev production
STAGE  ?= dev

ACCOUNT_ID_dev        := __DEV_ACCOUNT_ID__
ACCOUNT_ID_production := __PRODUCTION_ACCOUNT_ID__
PROFILE_dev           := __DEV_PROFILE__
PROFILE_production    := __PRODUCTION_PROFILE__

STACK        := __PREFIX__-platform-api
REGION       := __PRIMARY_REGION__
ACCOUNT_ID   := $(ACCOUNT_ID_$(STAGE))
EXEC_ROLE    := arn:aws:iam::$(ACCOUNT_ID):role/app-cfn-exec-role
PARAMS       := deployments/$(STAGE).json
SAM_TEMPLATE := $(CURDIR)/template.yaml
BUILD_DIR    := $(CURDIR)/.build/$(STAGE)
S3_PREFIX    := $(STACK)

PROFILE := $(if $(CI),,$(PROFILE_$(STAGE)))
VAULT   := $(if $(PROFILE),aws-vault exec $(PROFILE) --,)
AWS     := $(VAULT) aws --region $(REGION)
SAM     := $(VAULT) sam

CHANGE_SET        ?= manual-$(shell date -u +%Y%m%d%H%M%S)
ALLOW_DESTRUCTIVE ?=
# Compiled wheels must match the Lambda runtime: build in its image unless your
# python3 is the runtime's version. CI sets up that version and builds natively.
SAM_BUILD_FLAGS   ?= $(if $(CI),,--use-container)

export AWS SAM STACK REGION ACCOUNT_ID EXEC_ROLE PARAMS SAM_TEMPLATE BUILD_DIR S3_PREFIX CHANGE_SET ALLOW_DESTRUCTIVE SAM_BUILD_FLAGS

.DEFAULT_GOAL := help
.PHONY: help check ready changeset execute delete-changeset clean _stage

help: ## Show this help
	@echo "Usage: make <target> STAGE=<stage> [CHANGE_SET=<name>]    stages: $(STAGES)"
	@echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-17s %s\n", $$1, $$2}'

check: ## Unit tests, sam validate and every parameter file against the template (no AWS)
	@$(PYTHON) -m pytest -q -p no:cacheprovider tests
	@# Linting is offline; the region only has to be a real one.
	@sam validate --lint --region us-east-1 --template-file template.yaml
	@for s in $(STAGES); do ../bin/check-params "deployments/$$s.json" template.yaml || exit 1; done

ready: ## Fail while this component still has placeholders (no AWS)
	@../bin/ready .

changeset: _stage ready ## Build, package and create a change set for STAGE; executes nothing
	@LABEL="$(STACK) ($(STAGE))" ../bin/sam-changeset

execute: _stage ## Execute CHANGE_SET, which must still be CREATE_COMPLETE / AVAILABLE
	@[ "$(origin CHANGE_SET)" != file ] || { echo "name the change set: make execute STAGE=$(STAGE) CHANGE_SET=<name>"; exit 1; }
	@../bin/cfn-execute

delete-changeset: _stage ## Delete CHANGE_SET
	@[ "$(origin CHANGE_SET)" != file ] || { echo "name the change set: make delete-changeset STAGE=$(STAGE) CHANGE_SET=<name>"; exit 1; }
	@$(AWS) cloudformation delete-change-set --stack-name "$(STACK)" --change-set-name "$(CHANGE_SET)"
	@echo "deleted $(CHANGE_SET)"

clean: ## Remove the builds
	rm -rf .build .aws-sam

_stage:
	@case " $(STAGES) " in *" $(STAGE) "*) ;; \
	  *) echo "STAGE must be one of: $(STAGES)"; exit 1 ;; esac
	@[ -f "$(PARAMS)" ] || { echo "$(PARAMS) not found"; exit 1; }
