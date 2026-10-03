# events-observability — __TENANT__'s deployment of the SAR application
#
#   make check                                   every deployment file against the pinned product (no AWS)
#   make changeset STAGE=dev                     create and show a change set to SAR_VERSION; executes nothing
#   make execute STAGE=dev CHANGE_SET=<name>     execute a change set someone has read
#   make delete-changeset STAGE=dev CHANGE_SET=<name>
#
# The product is jnet-platform-factory/aws-eventbridge-firehose-opensearch-forwarder,
# deployed from the SAR application its own repository publishes. SAR_VERSION pins
# it, and is the one thing to move: TEMPLATE_REF is its release tag, so `check`
# reads the same version's parameters without AWS. Read the product's changes
# first, and expect `changeset` to show no Remove or Replacement.
#
# CI runs these in .github/workflows/events-observability.yml: a change set on
# every PR and on main, execute on main behind the eo-<stage> environment's
# reviewer. By hand, they run under aws-vault.
#
# STAGE    dev or production: picks deployments/<STAGE>.json, the account and the stack
# CI=true  (set by GitHub Actions) use the ambient credentials, not aws-vault

SHELL := /bin/bash

SAR_APPLICATION := AWS-EventBridge-Firehose-OpenSearch-Forwarder
SAR_VERSION     := 1.6.0
TEMPLATE_REF    := v$(SAR_VERSION)
TEMPLATE_URL    := https://raw.githubusercontent.com/jnet-platform-factory/aws-eventbridge-firehose-opensearch-forwarder/$(TEMPLATE_REF)/template.yaml

STAGES := dev production
STAGE  ?= dev

ACCOUNT_ID_dev        := __DEV_ACCOUNT_ID__
ACCOUNT_ID_production := __PRODUCTION_ACCOUNT_ID__
PROFILE_dev           := __DEV_PROFILE__
PROFILE_production    := __PRODUCTION_PROFILE__

# SAR is regional: the application must be published in the stack's region.
REGION     := __EO_REGION__
SAR_APP_ID := arn:aws:serverlessrepo:$(REGION):__SAR_PUBLISHER_ACCOUNT_ID__:applications/$(SAR_APPLICATION)
STACK      := __PREFIX__-events-observability-$(STAGE)
ACCOUNT_ID := $(ACCOUNT_ID_$(STAGE))
EXEC_ROLE  := arn:aws:iam::$(ACCOUNT_ID):role/__PREFIX__-platform-eo-cfn-exec
PARAMS     := deployments/$(STAGE).json
TENANT     := tenants/tenant.json

PROFILE := $(if $(CI),,$(PROFILE_$(STAGE)))
AWS     := $(if $(PROFILE),aws-vault exec $(PROFILE) --,) aws --region $(REGION)

CHANGE_SET        ?= manual-$(shell date -u +%Y%m%d%H%M%S)
ALLOW_DESTRUCTIVE ?=

export AWS SAR_APP_ID SAR_VERSION STACK ACCOUNT_ID EXEC_ROLE PARAMS CHANGE_SET ALLOW_DESTRUCTIVE

.DEFAULT_GOAL := help
.PHONY: help check ready changeset execute delete-changeset _stage

help: ## Show this help
	@echo "Usage: make <target> STAGE=<stage> [CHANGE_SET=<name>]    stages: $(STAGES)"
	@echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-17s %s\n", $$1, $$2}'
	@echo
	@echo "Product: $(SAR_APPLICATION) @ SAR $(SAR_VERSION) (public tag $(TEMPLATE_REF))"

check: ## Check every deployment file against the tenant map and the pinned template (no AWS)
	@bin/check "$(TENANT)" "$(TEMPLATE_URL)" "$(SAR_VERSION)" $(foreach s,$(STAGES),deployments/$(s).json)

ready: ## Fail while this component still has placeholders (no AWS)
	@../bin/ready .

changeset: _stage ready ## Create and describe a change set to SAR_VERSION; executes nothing
	@bin/changeset

execute: _stage ## Execute CHANGE_SET, which must still be CREATE_COMPLETE / AVAILABLE
	@[ "$(origin CHANGE_SET)" != file ] || { echo "name the change set: make execute STAGE=$(STAGE) CHANGE_SET=<name>"; exit 1; }
	@../bin/cfn-execute

delete-changeset: _stage ## Delete CHANGE_SET
	@[ "$(origin CHANGE_SET)" != file ] || { echo "name the change set: make delete-changeset STAGE=$(STAGE) CHANGE_SET=<name>"; exit 1; }
	@$(AWS) cloudformation delete-change-set --stack-name "$(STACK)" --change-set-name "$(CHANGE_SET)"
	@echo "deleted $(CHANGE_SET)"

_stage:
	@case " $(STAGES) " in *" $(STAGE) "*) ;; \
	  *) echo "STAGE must be one of: $(STAGES)"; exit 1 ;; esac
	@[ -f "$(PARAMS)" ] || { echo "$(PARAMS) not found"; exit 1; }
