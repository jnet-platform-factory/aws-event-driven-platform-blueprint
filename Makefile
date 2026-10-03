# Platform repository — every gate in one place
#
#   make check      every component's check, shellcheck, actionlint, cfn-lint, Terraform (no AWS)
#   make ready      fail while any placeholder is left (no AWS)
#
# Each component directory has its own Makefile with the targets that reach AWS
# (plan / apply, changeset / execute); see its README.

SHELL  := /bin/bash
PYTHON ?= python3

# Every directory with a Makefile is a component (lambda-layers/ holds one per layer).
COMPONENTS := $(patsubst %/Makefile,%,$(sort $(wildcard */Makefile) $(wildcard lambda-layers/*/Makefile)))
SCRIPTS    := $(sort $(wildcard bin/* */bin/* scripts/*.sh))
SHELL_SCRIPTS = $(shell for f in $(SCRIPTS); do [ -f "$$f" ] && head -1 "$$f" | grep -q 'bash' && echo "$$f"; done)

.DEFAULT_GOAL := help
.PHONY: help check ready lint components

help: ## Show this help
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-12s %s\n", $$1, $$2}'
	@echo
	@echo "Components: $(COMPONENTS)"

check: lint components ## Every gate that needs no AWS
	@echo "check: ok"

lint: ## shellcheck, actionlint and cfn-lint
	shellcheck $(SHELL_SCRIPTS)
	actionlint
	@if [ -f aws-account-bootstrap/ci-roles/template.yaml ]; then cfn-lint aws-account-bootstrap/ci-roles/template.yaml; fi

components: ## Each component's own `make check`
	@for c in $(COMPONENTS); do echo "== $$c"; $(MAKE) --no-print-directory -C "$$c" check PYTHON="$(PYTHON)" || exit 1; done

ready: ## Fail while any placeholder is left (no AWS)
	@bin/ready .

# >>> blueprint-only: bin/init removes everything down to the closing marker
.PHONY: init leak-check test-init

init: ## Render this blueprint into a tenant repository (reads init.env)
	@bin/init

leak-check: ## Fail if anything internal is in the tree (see scripts/leak-check.py)
	@$(PYTHON) scripts/leak-check.py

test-init: ## Render into a temporary copy with example answers, then check the result
	@scripts/test-init.sh
# <<< blueprint-only
