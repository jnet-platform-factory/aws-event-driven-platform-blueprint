# aws-daily-monitoring-report — __TENANT__'s deployment of the public tool
#
#   make check                                       every deployment file against the pinned template (no AWS)
#   make changeset STAGE=dev                         build, package and create a change set; executes nothing
#   make execute STAGE=dev CHANGE_SET=<name>         execute a change set someone has read
#   make delete-changeset STAGE=dev CHANGE_SET=<name>
#   make invoke STAGE=dev                            send a report now (a human, after a deploy)
#   make verify-pin                                  TOOL_REF is still on the tool's main (no AWS)
#
# The tool is jnet-platform-factory/aws-daily-monitoring-report. It has no tags,
# so it is pinned by commit: `fetch` clones exactly TOOL_REF into .tool/<sha>/
# (git-ignored) and refuses to run anything else. To upgrade, move TOOL_REF after
# reading the tool's changes, and expect `changeset` to show no Replacement.
#
# CI runs these in .github/workflows/aws-daily-monitoring-report.yml with the
# bootstrap's app-deploy-role, in the GitHub environment of the stage. By hand,
# they run under aws-vault.
#
# STAGE    dev or production: picks deployments/<STAGE>.json, the account and the profile
# CI=true  (set by GitHub Actions) use the ambient credentials, not aws-vault

SHELL := /bin/bash

TOOL_REPO := https://github.com/jnet-platform-factory/aws-daily-monitoring-report.git
TOOL_REF  := a0851d335c43058736f18c04ae413b5ed1f59059
TOOL_DIR  := $(CURDIR)/.tool/$(TOOL_REF)

STAGES := dev production
STAGE  ?= dev

ACCOUNT_ID_dev        := __DEV_ACCOUNT_ID__
ACCOUNT_ID_production := __PRODUCTION_ACCOUNT_ID__
PROFILE_dev           := __DEV_PROFILE__
PROFILE_production    := __PRODUCTION_PROFILE__

# One stack per account, in the primary region.
STACK      := aws-daily-monitoring-report
REGION     := __PRIMARY_REGION__
ACCOUNT_ID := $(ACCOUNT_ID_$(STAGE))
EXEC_ROLE  := arn:aws:iam::$(ACCOUNT_ID):role/app-cfn-exec-role
PARAMS     := deployments/$(STAGE).json
BUILD_DIR  := $(CURDIR)/.build/$(STAGE)

PROFILE := $(if $(CI),,$(PROFILE_$(STAGE)))
VAULT   := $(if $(PROFILE),aws-vault exec $(PROFILE) --,)
AWS     := $(VAULT) aws --region $(REGION)
SAM     := $(VAULT) sam

CHANGE_SET        ?= manual-$(shell date -u +%Y%m%d%H%M%S)
ALLOW_DESTRUCTIVE ?=

export AWS SAM TOOL_DIR TOOL_REF STACK REGION STAGE ACCOUNT_ID EXEC_ROLE PARAMS BUILD_DIR CHANGE_SET ALLOW_DESTRUCTIVE

.DEFAULT_GOAL := help
.PHONY: help fetch verify-pin check ready changeset execute delete-changeset invoke clean _stage

help: ## Show this help
	@echo "Usage: make <target> STAGE=<stage> [CHANGE_SET=<name>]    stages: $(STAGES)"
	@echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-17s %s\n", $$1, $$2}'
	@echo
	@echo "Tool:  $(TOOL_REPO) @ $(TOOL_REF) (no tags upstream)"
	@echo "Stack: $(STACK), $(REGION), one per account"

fetch: $(TOOL_DIR)/.pinned ## Clone the tool at TOOL_REF into .tool/ (no AWS)
	@git -C "$(TOOL_DIR)" diff --quiet HEAD -- || \
	  { echo "$(TOOL_DIR) has local edits: run 'make clean' and fetch again"; exit 1; }

$(TOOL_DIR)/.pinned:
	@rm -rf "$(TOOL_DIR)" && mkdir -p "$(TOOL_DIR)"
	@git -C "$(TOOL_DIR)" init -q
	@git -C "$(TOOL_DIR)" fetch -q --depth 1 "$(TOOL_REPO)" "$(TOOL_REF)"
	@git -C "$(TOOL_DIR)" -c advice.detachedHead=false checkout -q FETCH_HEAD
	@test "$$(git -C "$(TOOL_DIR)" rev-parse HEAD)" = "$(TOOL_REF)" || \
	  { echo "fetched commit is not $(TOOL_REF)"; rm -rf "$(TOOL_DIR)"; exit 1; }
	@touch "$@"
	@echo "aws-daily-monitoring-report $(TOOL_REF) in $(TOOL_DIR)"

# With no tag to compare against, the guarantee is that the pinned commit is
# still part of the tool's main: a rewritten main would orphan it.
verify-pin: ## Fail if TOOL_REF is no longer on the tool's main (no AWS)
	@tmp="$$(mktemp -d)"; trap 'rm -rf "$$tmp"' EXIT; \
	git -C "$$tmp" init -q && git -C "$$tmp" fetch -q --filter=blob:none "$(TOOL_REPO)" main && \
	if git -C "$$tmp" merge-base --is-ancestor "$(TOOL_REF)" FETCH_HEAD 2>/dev/null; then \
	  echo "$(TOOL_REF) is on main, $$(git -C "$$tmp" rev-list --count "$(TOOL_REF)..FETCH_HEAD") commit(s) behind it"; \
	else echo "$(TOOL_REF) is not on the tool's main any more: review before re-pinning"; exit 1; fi; \
	tags="$$(git ls-remote --tags "$(TOOL_REPO)" | wc -l | tr -d ' ')"; \
	[ "$$tags" = 0 ] || echo "NOTE: the tool now has $$tags tag ref(s); consider pinning a tag"

check: fetch ## Check every deployment file against the pinned template, and sam validate it (no AWS)
	@for s in $(STAGES); do bin/check "deployments/$$s.json" "$(TOOL_DIR)/template.yaml" "__PREFIX__-$$s" || exit 1; done
	@# Linting is offline; the region only has to be a real one.
	@sam validate --lint --region us-east-1 --template-file "$(TOOL_DIR)/template.yaml"

ready: ## Fail while this component still has placeholders (no AWS)
	@../bin/ready .

changeset: _stage ready fetch ## Build, package and create a change set for STAGE; executes nothing
	@bin/check "$(PARAMS)" "$(TOOL_DIR)/template.yaml" "__PREFIX__-$(STAGE)" >/dev/null
	@bin/changeset

execute: _stage ## Execute CHANGE_SET, which must still be CREATE_COMPLETE / AVAILABLE
	@[ "$(origin CHANGE_SET)" != file ] || { echo "name the change set: make execute STAGE=$(STAGE) CHANGE_SET=<name>"; exit 1; }
	@../bin/cfn-execute

delete-changeset: _stage ## Delete CHANGE_SET
	@[ "$(origin CHANGE_SET)" != file ] || { echo "name the change set: make delete-changeset STAGE=$(STAGE) CHANGE_SET=<name>"; exit 1; }
	@$(AWS) cloudformation delete-change-set --stack-name "$(STACK)" --change-set-name "$(CHANGE_SET)"
	@echo "deleted $(CHANGE_SET)"

# Sends a real email, and writes the snapshot: a human checking a deploy, never CI.
invoke: _stage ## Send a report now; prints statusCode and snapshotWritten
	@[ -z "$(CI)" ] || { echo "invoke is for a human checking a deploy, never CI"; exit 1; }
	@$(AWS) lambda invoke --function-name aws-daily-monitoring-report --payload '{}' \
	  --cli-binary-format raw-in-base64-out /dev/stdout

clean: ## Remove the fetched tool and the builds
	rm -rf .tool .build

_stage:
	@case " $(STAGES) " in *" $(STAGE) "*) ;; \
	  *) echo "STAGE must be one of: $(STAGES)"; exit 1 ;; esac
	@[ -f "$(PARAMS)" ] || { echo "$(PARAMS) not found"; exit 1; }
