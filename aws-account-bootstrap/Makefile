# aws-account-bootstrap — __TENANT__'s configuration for the public tool
#
#   make check                    pin, configs, scripts and the CI roles template (no AWS)
#   make plan  ACCOUNT=dev        show every change and policy document (read-only)
#   make analyze ACCOUNT=dev      Access Analyzer + IAM simulator checks (read-only; the tool's `check`)
#   make diff  ACCOUNT=dev        rendered documents against live IAM; exit 1 on drift
#   make apply ACCOUNT=dev        create / update the roles: CI behind a reviewer, or a human
#   make ci-roles ACCOUNT=dev     deploy ci-roles/ (the roles CI assumes): a human, never CI
#
# The tool itself lives in jnet-platform-factory/aws-account-bootstrap. This file
# only pins it and points it at configs/<ACCOUNT>.env: no tool code is copied here.
# `fetch` clones exactly TOOL_REF into .tool/<sha>/ (git-ignored) and refuses to run
# anything else. To upgrade, change TOOL_TAG and TOOL_REF together, after reading
# the tool's changelog and running `make plan` and `make diff` against every account.
#
# ACCOUNT  one of ACCOUNTS below — picks the config and the aws-vault profile
# YES=1    apply without the confirmation prompt
# CI=true  (set by GitHub Actions) use the ambient credentials, not aws-vault, and
#          leave the other repositories' GitHub environments alone

SHELL := /bin/bash

TOOL_REPO := https://github.com/jnet-platform-factory/aws-account-bootstrap.git
TOOL_TAG  := v0.0.3
TOOL_REF  := 9c5943fc3a9a9130783817eba3320332d4135b11
TOOL_DIR  := $(CURDIR)/.tool/$(TOOL_REF)

ACCOUNTS := dev production
ACCOUNT  ?=
YES      ?=

# aws-vault profile per account config. The AWS account is in each config's
# first line. In CI there is no profile: the workflow has already assumed the
# account's bootstrap ci-role through OIDC.
PROFILE_dev        := __DEV_PROFILE__
PROFILE_production := __PRODUCTION_PROFILE__
PROFILE  := $(if $(CI),,$(PROFILE_$(ACCOUNT)))
CONFIG   := $(CURDIR)/configs/$(ACCOUNT).env
AWS_EXEC := $(if $(PROFILE),aws-vault exec $(PROFILE) --,)

# The GitHub environments, read from the config so there is one list. The
# config's PLATFORM_ENVIRONMENTS and APP_ENVIRONMENTS win over ENV inside the
# tool; ENV is passed because it is the tool's interface for them.
ENV := $(shell sed -n 's/^PLATFORM_ENVIRONMENTS="\(.*\)"$$/\1/p' $(CONFIG) 2>/dev/null)

# Accounts `apply` must refuse at this TOOL_REF; plan, check and diff stay allowed.
# Put an account here when its plan shows something you have not decided to
# change — an existing role this config would rewrite, say — and take it out in
# a reviewed change once you have. Empty is not the same as safe: read the plan.
NO_APPLY :=

# In CI, CONFIGURE_GITHUB=false: apply never creates environments or sets
# variables in another repository from here. SECURITY_GROUP=no: infrastructure/
# owns this account's VPC and security groups.
TOOL := SECURITY_GROUP=no $(if $(CI),CONFIGURE_GITHUB=false,) $(MAKE) --no-print-directory -C $(TOOL_DIR) \
          PROFILE=$(PROFILE) CONFIG=$(CONFIG) ENV="$(ENV)"

# ci-roles/: one stack per account, in the primary region.
CI_ROLES_STACK  := __PREFIX__-platform-ci-roles
CI_ROLES_REGION := __PRIMARY_REGION__
CI_ROLES_PARAMS := Account=$(ACCOUNT) Prefix=__PREFIX__ \
                   GitHubOrg=__GITHUB_ORG__ GitHubOrgId=__GITHUB_ORG_ID__ \
                   GitHubRepo=__PLATFORM_REPO__ GitHubRepoId=__PLATFORM_REPO_ID__ \
                   EventsObservability=__EVENTS_OBSERVABILITY__ EventsObservabilityRegion=__EO_REGION__ \
                   SarPublisherAccountId=__SAR_PUBLISHER_ACCOUNT_ID__

.DEFAULT_GOAL := help
.PHONY: help check fetch plan analyze diff apply github-oidc ci-roles verify-pin same-account ready clean _account _applicable

help: ## Show this help
	@echo "Usage: make <target> ACCOUNT=<account>    accounts: $(ACCOUNTS)"
	@echo
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'
	@echo
	@echo "Tool: $(TOOL_REPO) @ $(TOOL_TAG) ($(TOOL_REF))"

check: same-account fetch ## Pin, configs, scripts and the CI roles template (no AWS)
	@shellcheck bin/diff-live bin/github-oidc
	@cfn-lint ci-roles/template.yaml
	@echo "check: ok"

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
	@echo "aws-account-bootstrap $(TOOL_TAG) ($(TOOL_REF)) in $(TOOL_DIR)"

verify-pin: ## Fail if TOOL_TAG no longer points at TOOL_REF upstream (no AWS)
	@remote="$$(git ls-remote "$(TOOL_REPO)" "refs/tags/$(TOOL_TAG)" | cut -f1)"; \
	if [ "$$remote" = "$(TOOL_REF)" ]; then echo "$(TOOL_TAG) = $(TOOL_REF)"; \
	else echo "$(TOOL_TAG) is now '$$remote', pinned $(TOOL_REF): review before re-pinning"; exit 1; fi

# Every run rewrites each role's trust policy from one config file alone, so two
# configs for the SAME AWS account must agree, or applying one silently locks out
# what only the other allows. The blueprint gives every environment its own
# account; this keeps any later exception honest, grouping the configs by the
# account named in their first line.
same-account: ## Fail if two configs for one AWS account differ outside comments (no AWS)
	@for a in $$(awk 'FNR == 1 && match($$0, /account [0-9]+/) { print substr($$0, RSTART + 8, RLENGTH - 8) }' configs/*.env | sort | uniq -d); do \
	  set -- $$(grep -l "^# .*account $$a" configs/*.env); first="$$1"; shift; \
	  for f in "$$@"; do \
	    diff <(grep -vE '^[[:space:]]*(#|$$)' "$$first") <(grep -vE '^[[:space:]]*(#|$$)' "$$f") >/dev/null || \
	      { echo "$$first and $$f must agree: they configure one AWS account"; exit 1; }; \
	  done; \
	done

ready: ## Fail while this component still has placeholders (no AWS)
	@../bin/ready .

# The trust policies are rendered from what gh reads, and a failed read silently
# drops the immutable subject form: so every target that renders one checks first.
github-oidc: _account ## Fail if gh cannot read a configured repo's OIDC subject setting (no AWS)
	@bin/github-oidc "$(CONFIG)"

plan: _account ready same-account fetch github-oidc ## Show the plan and every policy document; changes nothing
	@$(TOOL) plan

analyze: _account ready same-account fetch ## Validate the rendered policies with Access Analyzer + IAM simulator (read-only AWS calls)
	@$(TOOL) check

diff: _account ready same-account fetch github-oidc ## Compare the rendered documents with live IAM; exit 1 on any difference
	@$(AWS_EXEC) bin/diff-live "$(TOOL_DIR)" "$(CONFIG)"

apply: _account _applicable ready same-account fetch github-oidc ## Create or update the roles in the account
	@$(TOOL) apply $(if $(YES),YES=1,)

# The roles this repository's own workflows assume for the bootstrap and for
# events-observability. Not part of the bootstrap on purpose: an apply that goes
# wrong must not take away the pipeline that would fix it.
ci-roles: _account ready ## Deploy ci-roles/template.yaml into the account (a human, under aws-vault)
	@[ -z "$(CI)" ] || { echo "ci-roles is deployed by a human, never CI"; exit 1; }
	@$(AWS_EXEC) aws cloudformation deploy --region $(CI_ROLES_REGION) --stack-name $(CI_ROLES_STACK) \
	  --template-file ci-roles/template.yaml --capabilities CAPABILITY_NAMED_IAM \
	  --parameter-overrides $(CI_ROLES_PARAMS) --no-fail-on-empty-changeset

clean: ## Remove the fetched tool
	rm -rf .tool

_account:
	@case " $(ACCOUNTS) " in *" $(ACCOUNT) "*) ;; \
	  *) echo "ACCOUNT must be one of: $(ACCOUNTS)"; exit 1 ;; esac
	@[ -f "$(CONFIG)" ] || { echo "$(CONFIG) not found"; exit 1; }

_applicable:
	@case " $(NO_APPLY) " in *" $(ACCOUNT) "*) \
	  echo "$(ACCOUNT) cannot be applied with $(TOOL_TAG) ($(TOOL_REF)): see NO_APPLY in this Makefile"; exit 1 ;; esac
