# CLAUDE.md

Guidance for coding agents (Claude Code, Codex and others; `AGENTS.md` is a link to this
file) working in ****PLATFORM_REPO****, ****TENANT****'s platform repository. People
read [README.md](README.md) for the same map; the rules are in [PLATFORM.md](PLATFORM.md)
and win over anything here.

## What this repository is

The configuration of ****TENANT****'s AWS accounts and every deploy into them. It holds no
tool code: the tools are public, in `jnet-platform-factory`, and each component pins one
by tag or full commit. It was rendered from `aws-event-driven-platform-blueprint`; it does
not track it.

| Environment  | AWS account                 | aws-vault profile        |
| ------------ | --------------------------- | ------------------------ |
| `dev`        | `__DEV_ACCOUNT_ID__`        | `__DEV_PROFILE__`        |
| `production` | `__PRODUCTION_ACCOUNT_ID__` | `__PRODUCTION_PROFILE__` |

Regions: `__PRIMARY_REGION__` for workloads, `__EO_REGION__` for events-observability and
the event bus. Resource names start with `__PREFIX__`. Components: `__COMPONENTS__`.

## How every component works

- One top-level directory (layers under `lambda-layers/<name>/`) with a `Makefile`,
  a `README.md`, and for a stack `deployments/<stage>.json`.
- `make check` needs no AWS. Run it — or `make check` at the root for everything —
  after any change. It is what the `Check` workflow runs.
- Targets that reach AWS are **`changeset` / `execute`** (a CloudFormation stack) or
  **`plan` / `apply`** (anything else), with `STAGE=` or `ENV=` `dev` | `production`.
  Every one depends on `ready`, which fails while a `CHANGEME` (or an unrendered token) is left.
- Every deploy is a change set or a plan that a person reads, made in one job and run in
  another: dev on merge to `main`, production behind its reviewers. The shared pieces are
  `bin/cfn-changeset`, `bin/cfn-execute`, `bin/sam-changeset`, `bin/check-params` and the
  reusable `.github/workflows/cfn-changeset.yml`.
- A parameter file lists **every** template parameter, empty ones too: one left out
  silently takes the template's default. `bin/check-params` enforces it.
- Credentials come from the GitHub environment named after the AWS environment
  (`AWS_PLATFORM_ROLE_ARN` for Terraform and SSM, `AWS_APP_ROLE_ARN` for stacks), set by
  `aws-account-bootstrap`. Locally, through the aws-vault profile above.

<!-- infrastructure -->

## Infrastructure and the SSM bridge

`infrastructure/live/<env>/<region>/<unit>/terragrunt.hcl` — the directory picks the
account and region; `live/root.hcl` holds state and provider, `live/platform.hcl` what
differs between environments. Modules are plain Terraform in `infrastructure/modules/`.

`platform-resources` publishes what applications need as **String** parameters under
`/platform/<env>/` (VPC, subnets, security groups, VPC Link, zone, certificate,
AppConfig ids, logs bucket); `event-bus` publishes `/platform/<env>/event_bus_name` and
`event_bus_arn` in `__EO_REGION__`. A SAM template reads them as
`AWS::SSM::Parameter::Value<String>` parameters. Secrets go through `ssm-parameters/`,
never through Terraform.

<!-- /infrastructure -->

## Rules you must keep

- **Never rename a live name**: stack, function, bucket, bus, IAM role or parameter.
  CloudFormation and Terraform read a rename as delete-and-create.
- **Never deploy from your session.** Make the change, run `make check`, and let a pull
  request show the plan or change set. `plan` / `changeset` are read-only and fine to run
  when asked; `apply`, `execute`, `ci-roles` and `sso-apply` are a person's decision.
- **Read every change set and plan for Remove and Replacement.** They are refused unless
  `ALLOW_DESTRUCTIVE=1`; never set it to get past a failure.
- **Secrets are GitHub environment secrets**, mapped in a workflow's `env:` block —
  never Actions variables, never committed, never in Terraform state, never in a job
  summary. Account ids and ARNs stay out of summaries too.
- **Pins move in reviewed pull requests**, tag and commit together, after reading the
  tool's changes; `make verify-pin` checks them.
- **App-owned infrastructure lives in the app's repository**, not here. This repository
  owns the accounts' shared foundation.

## Adding something

- A component: follow [docs/adding-a-component.md](docs/adding-a-component.md) — a directory with the Makefile contract,
  a workflow triggered by its own paths, and its row in README.md.
- An SSM parameter: an entry in `ssm-parameters/ssm-parameters.json` under
  `/__PREFIX__/{environment}/...`; a secret is `source_env`, mapped from the environment's
  secrets in `.github/workflows/ssm-parameters.yml`.
