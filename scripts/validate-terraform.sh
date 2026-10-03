#!/usr/bin/env bash
# validate-terraform.sh: `terraform fmt -check` and `terraform validate` on every
# module under infrastructure/modules, and `terragrunt hcl fmt --check` on
# infrastructure/live. No AWS: modules are initialised without a backend.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
modules="${root}/infrastructure/modules"
live="${root}/infrastructure/live"
[[ -d "${modules}" ]] || { echo "validate-terraform: no infrastructure/ here, nothing to do"; exit 0; }

terraform fmt -check -recursive "${modules}"
echo "terraform fmt: ok"

for dir in "${modules}"/*/; do
  name="$(basename "${dir}")"
  terraform -chdir="${dir}" init -backend=false -input=false >/dev/null
  terraform -chdir="${dir}" validate -no-color >/dev/null
  echo "terraform validate: ${name} ok"
done

if command -v terragrunt >/dev/null; then
  terragrunt hcl fmt --check --working-dir "${live}"
  echo "terragrunt hcl fmt: ok"
else
  echo "terragrunt not installed: skipping hcl fmt"
fi
