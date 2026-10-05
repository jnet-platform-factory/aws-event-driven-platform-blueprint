# Adding a component

A component is one thing the platform deploys, with its configuration, its gates and
its pipeline. The blueprint's components all follow the same contract, so a new one —
in the blueprint, or in one tenant's repository — is added the same way.

## The contract

1. **One top-level directory** (or `lambda-layers/<name>/` for a layer) with:
   - a **`Makefile`** whose `check` target needs no AWS credentials, and whose targets
     that reach AWS are either `changeset` / `execute` / `delete-changeset` (a
     CloudFormation stack) or `plan` / `apply` (anything else), each taking `STAGE` or
     `ENV` (`dev`, `production`). Every target that reaches AWS depends on `ready`
     (`@../bin/ready .`). Under `CI=true` it uses the ambient credentials; by hand, the
     environment's aws-vault profile.
   - a **`README.md`**: what it deploys, where (stack, account, region), what to fill in,
     how to deploy, and the rules that protect it.
   - **`deployments/<stage>.json`** for a stack: every template parameter, in
     `create-change-set --parameters` form, checked with `../bin/check-params`.
2. **A workflow**, `.github/workflows/<component>.yml`, triggered by its own paths:
   - a `check` job with no AWS (`make -C <component> check`);
   - for a stack, `dev` and `production` jobs that call
     [cfn-changeset.yml](../.github/workflows/cfn-changeset.yml), the `production` one only on
     `main`;
   - the repository guard on every job that reaches AWS,
     `github.repository == '__GITHUB_ORG__/__PLATFORM_REPO__'`: in the blueprint the name
     is still a token, so the blueprint (and any fork or copy of a tenant repository)
     never deploys;
   - a `summary` job through the shared job-summary action, with `permissions: {}`.
3. **Credentials** from the bootstrap: `AWS_APP_ROLE_ARN` for stacks,
   `AWS_PLATFORM_ROLE_ARN` for Terraform and SSM. A component that needs more than those
   roles allow gets its own roles in
   [aws-account-bootstrap/ci-roles/template.yaml](../aws-account-bootstrap/ci-roles/template.yaml),
   behind a condition, as events-observability does.
4. **Deploying a public tool**: pin it (tag + commit, or commit), fetch it into `.tool/<sha>`,
   and give the Makefile a `verify-pin` target — never copy its code.

## In the blueprint

Also:

- add the directory to `ALL_COMPONENTS` in [bin/init](../bin/init), and its workflow to
  `workflows_of` if the names differ;
- if it has Python requirements, give it a pip entry in
  [.github/dependabot.yml](../.github/dependabot.yml) between `# >>> <component>` and
  `# <<< <component>`, so `bin/init` removes the entry with the component;
- use only the identity tokens `bin/init` knows (its `tokens` list) and `CHANGEME`
  for values a tenant chooses — `make test-init` fails on any other token;
- add it to the component table in [README.md](../README.md) and the pipelines table in
  [README.tenant.md](../README.tenant.md); if it changes how things deploy, say so in
  [CLAUDE.tenant.md](../CLAUDE.tenant.md) too.

`make test-init` renders every component, so the new one is checked in a rendered
repository on every pull request.
