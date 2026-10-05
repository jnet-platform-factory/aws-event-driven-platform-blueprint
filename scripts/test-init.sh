#!/usr/bin/env bash
# test-init.sh: render the blueprint into temporary copies with example answers,
# and check each result as a tenant repository would be checked. No AWS.
#
#   full      every component; events-observability in a second region, so the
#             event bus has a region directory of its own
#   minimal   bootstrap, events-observability and ssm-parameters only, one region,
#             so the two region directories merge
#
# For each: bin/init succeeds and leaves no token; the blueprint-only files are
# gone; `make check` passes; `make ready` fails while CHANGEME is left and passes
# once it is filled in; every AWS job is guarded to the rendered repository; and
# (full) Terragrunt evaluates every dependency-free unit from its path — account,
# region and component — without AWS.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
PYTHON="${PYTHON:-python3}"
work="$(mktemp -d)"; trap 'rm -rf "${work}"' EXIT
fail() { echo "test-init: FAIL: $*" >&2; exit 1; }

render() {  # render <name> <answers...>: a fresh copy, rendered; its path in RENDERED
  local dir="${work}/$1"; shift
  mkdir -p "${dir}"
  rsync -a --exclude .git --exclude .tool --exclude .build --exclude .aws-sam --exclude .terraform \
    --exclude .terragrunt-cache --exclude .leak-check-deny --exclude init.env --exclude __pycache__ \
    "${root}/" "${dir}/"
  printf '%s\n' "$@" > "${dir}/init.env"
  # A rendered repository is a git checkout: actionlint finds the workflows from it.
  git -C "${dir}" init -q
  (cd "${dir}" && bin/init) >&2 || fail "bin/init failed for $(basename "${dir}")"
  RENDERED="${dir}"
}

expect_ready_after_filling() {  # <dir>
  local dir="$1"
  if (cd "${dir}" && make ready) >/dev/null 2>&1; then fail "make ready passed with CHANGEME left"; fi
  # What a person would write in place of each CHANGEME.
  # bin/ready names the placeholder it looks for; that is not one to fill in.
  grep -rlI --exclude-dir=.git --exclude-dir=.tool --exclude='*.md' --exclude=ready CHANGEME "${dir}" | while IFS= read -r f; do
    sed -i.bak 's/CHANGEME@example\.com/ops@example.com/g; s/arn:aws:es:\([a-z0-9-]*\):CHANGEME:/arn:aws:es:\1:123456789012:/g; s/CHANGEME/example/g' "${f}"
    rm -f "${f}.bak"
  done
  (cd "${dir}" && make ready) || fail "make ready still fails after filling in"
}

# The blueprint itself: every job that reaches AWS is guarded by a token, so it
# never runs here, and no guard names a repository by hand.
echo "== blueprint guards"
if grep -rn "github.repository !=" "${root}/.github/workflows"; then fail "a workflow guards by excluding a name"; fi
grep -rq "github.repository == '__GITHUB_ORG__/__PLATFORM_REPO__'" "${root}/.github/workflows" ||
  fail "no workflow has the rendered repository guard"

expect_guarded() {  # <dir> <org/repo>: every repository guard in the rendered workflows names it
  local dir="$1" repo="$2" guards
  guards="$(grep -rhoE "github.repository == '[^']*'" "${dir}/.github/workflows" | sort -u)"
  [[ "${guards}" == "github.repository == '${repo}'" ]] ||
    fail "$(basename "${dir}"): the workflows' guards are not all ${repo}: ${guards}"
}

common=(
  'TENANT="Acme Freight"' 'PREFIX="acme"' 'GITHUB_ORG="acme-org"' 'PLATFORM_REPO="acme-platform"'
  'GITHUB_ORG_ID="1001"' 'PLATFORM_REPO_ID="2002"'
  'DEV_ACCOUNT_ID="111122223333"' 'PRODUCTION_ACCOUNT_ID="444455556666"'
  'SAR_PUBLISHER_ACCOUNT_ID="123456789012"'
)

# --- full ------------------------------------------------------------------------
echo "== full: every component, two regions"
render full "${common[@]}" 'APP_REPOS="acme-api acme-web"' 'PRIMARY_REGION="us-west-2"' 'EO_REGION="us-east-1"' \
  'MANAGEMENT_PROFILE="acme-management"'
full="${RENDERED}"

for gone in bin/init init.env.example LICENSE scripts/leak-check.py scripts/test-init.sh .github/workflows/blueprint.yml README.tenant.md CLAUDE.tenant.md; do
  [[ ! -e "${full}/${gone}" ]] || fail "full: ${gone} survived init"
done
[[ -f "${full}/CLAUDE.md" && "$(readlink "${full}/AGENTS.md")" == CLAUDE.md ]] || fail "full: no CLAUDE.md, or AGENTS.md is not a link to it"
grep -q 'Infrastructure and the SSM bridge' "${full}/CLAUDE.md" || fail "full: CLAUDE.md lost its infrastructure section"
expect_guarded "${full}" acme-org/acme-platform
grep -q '^PROFILE_management := acme-management$' "${full}/aws-account-bootstrap/Makefile" || fail "full: the management profile"
grep -q 'sso-plan' "${full}/README.md" || fail "full: README.md has no Identity Center step"
for d in /platform-api/src /lambda-layers/base-layer/layer; do
  grep -q "directory: \"${d}\"" "${full}/.github/dependabot.yml" || fail "full: dependabot.yml has no ${d}"
done
grep -q 'blueprint-only' "${full}/Makefile" && fail "full: the Makefile kept its blueprint-only targets"
grep -q '^APP_REPOS="acme-platform acme-api acme-web"$' "${full}/aws-account-bootstrap/configs/dev.env" ||
  fail "full: APP_REPOS is not the platform repository followed by the others"
grep -q '^ALLOWED_REGIONS="us-west-2 us-east-1"$' "${full}/aws-account-bootstrap/configs/dev.env" ||
  fail "full: ALLOWED_REGIONS is not both regions"
[[ -f "${full}/infrastructure/live/dev/us-west-2/vpc/terragrunt.hcl" ]] || fail "full: no live/dev/us-west-2/vpc"
[[ -f "${full}/infrastructure/live/production/us-east-1/event-bus/terragrunt.hcl" ]] || fail "full: no live/production/us-east-1/event-bus"

(cd "${full}" && make check PYTHON="${PYTHON}") || fail "full: make check"
expect_ready_after_filling "${full}"

# Terragrunt evaluates root.hcl from each unit's path: the account, the region and
# the state key all follow from the directory, with no AWS call.
if command -v terragrunt >/dev/null; then
  for unit in dev/us-west-2/vpc production/us-west-2/route53 dev/us-west-2/aws-appconfig production/us-east-1/event-bus; do
    out="$(terragrunt render --format json --non-interactive --working-dir "${full}/infrastructure/live/${unit}" 2>/dev/null)" ||
      fail "full: terragrunt cannot evaluate ${unit}"
    env="${unit%%/*}"; region="$(cut -d/ -f2 <<<"${unit}")"
    account="$([[ "${env}" == dev ]] && echo 111122223333 || echo 444455556666)"
    jq -e --arg key "${unit}/terraform.tfstate" --arg bucket "acme-terraform-state-${account}" \
      '.remote_state.config.key == $key and .remote_state.config.bucket == $bucket' <<<"${out}" >/dev/null ||
      fail "full: ${unit} does not resolve to its own account's state"
    grep -q "allowed_account_ids = \[\"${account}\"\]" <<<"$(jq -r '.generate.provider.contents' <<<"${out}")" ||
      fail "full: ${unit}'s provider is not locked to ${account}"
    grep -q "region = \"${region}\"" <<<"$(jq -r '.generate.provider.contents' <<<"${out}")" ||
      fail "full: ${unit}'s provider is not in ${region}"
    echo "terragrunt: ${unit} -> account ${account}, ${region}"
  done
else
  echo "terragrunt not installed: skipping the unit evaluation"
fi

# --- minimal ---------------------------------------------------------------------
echo "== minimal: three components, one region"
render minimal "${common[@]}" 'PRIMARY_REGION="eu-west-1"' 'COMPONENTS="aws-account-bootstrap events-observability ssm-parameters"'
minimal="${RENDERED}"

for gone in infrastructure platform-api lambda-layers aws-daily-monitoring-report \
            .github/workflows/infrastructure.yml .github/workflows/platform-api.yml \
            .github/workflows/lambda-layer.yml .github/workflows/aws-daily-monitoring-report.yml; do
  [[ ! -e "${minimal}/${gone}" ]] || fail "minimal: ${gone} survived init"
done
grep -q 'EventsObservability=true' "${minimal}/aws-account-bootstrap/Makefile" || fail "minimal: the eo CI roles are off"
expect_guarded "${minimal}" acme-org/acme-platform
grep -q 'platform-api\|lambda-layers' "${minimal}/.github/dependabot.yml" && fail "minimal: dependabot.yml kept a removed component"
grep -q 'Infrastructure and the SSM bridge' "${minimal}/CLAUDE.md" && fail "minimal: CLAUDE.md kept the infrastructure section"
# No management profile: no Identity Center step, and the targets refuse before any AWS.
grep -q 'sso-plan' "${minimal}/README.md" && fail "minimal: README.md has an Identity Center step without a profile"
out="$(make -C "${minimal}/aws-account-bootstrap" sso-plan 2>&1)" && fail "minimal: sso-plan ran without a management profile"
grep -q 'no management account profile' <<<"${out}" || fail "minimal: sso-plan did not say why it refused: ${out}"
grep -q '^ALLOWED_REGIONS="eu-west-1"$' "${minimal}/aws-account-bootstrap/configs/dev.env" || fail "minimal: ALLOWED_REGIONS"

(cd "${minimal}" && make check PYTHON="${PYTHON}") || fail "minimal: make check"
expect_ready_after_filling "${minimal}"

# --- refusals --------------------------------------------------------------------
echo "== refusals"
refuse() {  # refuse <why> <answers...>
  local why="$1" dir="${work}/refuse"; shift
  rm -rf "${dir}"; mkdir -p "${dir}"
  rsync -a --exclude .git --exclude .tool --exclude .build --exclude .terraform --exclude .terragrunt-cache "${root}/" "${dir}/"
  printf '%s\n' "$@" > "${dir}/init.env"
  if (cd "${dir}" && bin/init) >/dev/null 2>&1; then fail "init accepted ${why}"; fi
  [[ -f "${dir}/bin/init" ]] || fail "init changed files before refusing ${why}"
  echo "refused: ${why}"
}
refuse "one account for both environments" "${common[@]/444455556666/111122223333}" 'PRIMARY_REGION="us-east-1"'
refuse "platform-api without infrastructure" "${common[@]}" 'PRIMARY_REGION="us-east-1"' \
  'COMPONENTS="aws-account-bootstrap platform-api"'
refuse "a bad region" "${common[@]}" 'PRIMARY_REGION="us-east"'
refuse "a bad management profile" "${common[@]}" 'PRIMARY_REGION="us-east-1"' 'MANAGEMENT_PROFILE="acme management"'

echo
echo "test-init: ok"
