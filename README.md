# platform-blueprint

The base model for a **tenant platform repository**: the one private repository that
holds a tenant's AWS configuration and runs every deploy into its accounts. Create a
repository from this template, answer a dozen questions, and you have the account
bootstrap, a Terragrunt foundation, events observability, daily monitoring, SSM
parameters, a platform API and a shared Lambda layer — each with its own CI/CD, each
pinned to the public tools in [jnet-platform-factory](https://github.com/jnet-platform-factory).

This repository holds no tenant data. Everything tenant-specific is a token that
`bin/init` fills in, or a `CHANGEME` you replace. The model behind it is in
[PLATFORM.md](PLATFORM.md).

## Quickstart

1. **Create the repository** with **Use this template** (private), and clone it.
2. **Answer the questions**: `cp init.env.example init.env`, then edit `init.env` —
   tenant name and prefix, GitHub org and repository, one AWS account per environment,
   regions, and the components to keep.
3. **Render**: `make init`. It checks every answer before writing anything, looks up the
   GitHub ids with `gh`, removes the components you did not ask for, fills in every
   token, and leaves a tenant README in place of this one.
4. **Fill in and commit**: `make ready` lists the `CHANGEME` values left (domains,
   addresses, the OpenSearch domain). Review the diff, commit, and follow the new
   README's _First deploy, in order_.

## Components

| Component                                                  | Deploys                                                                                                     | With                                 |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------ |
| [aws-account-bootstrap](aws-account-bootstrap)             | GitHub OIDC and the keyless deploy roles in each account (required)                                         | the public tool, pinned; `ci-roles/` |
| [infrastructure](infrastructure)                           | VPC, security groups, VPC Link, hosted zone, certificate, AppConfig, event bus, logs bucket, the SSM bridge | Terragrunt + Terraform modules       |
| [events-observability](events-observability)               | EventBridge → Firehose → OpenSearch, with an error digest                                                   | the public SAR application, pinned   |
| [aws-daily-monitoring-report](aws-daily-monitoring-report) | a daily health and cost email per account                                                                   | the public tool, pinned              |
| [ssm-parameters](ssm-parameters)                           | declared SSM parameters, secrets from GitHub environments                                                   | a reconciler script                  |
| [platform-api](platform-api)                               | `GET /platform/info`, the SSM bridge end to end — the pattern for SAM applications                          | SAM                                  |
| [lambda-layers/base-layer](lambda-layers/base-layer)       | the shared Python layer                                                                                     | SAM                                  |

Every component has a `Makefile` with an offline `check`, and targets that reach AWS
only through a plan or a change set that someone reads; and a workflow that shows it on a
pull request, applies dev on merge, and production behind its reviewers. The shared
pieces are in [bin/](bin) (`cfn-changeset`, `cfn-execute`, `sam-changeset`, `check-params`,
`ready`) and [.github/workflows/cfn-changeset.yml](.github/workflows/cfn-changeset.yml).

## Working on the blueprint

```bash
make check       # every component's check, shellcheck, actionlint, cfn-lint, Terraform
make leak-check  # nothing internal in the tree: this repository is public
make test-init   # render with example answers, in two shapes, and check each result
```

The `Check` and `Blueprint` workflows run these on every pull request. The jobs that
reach AWS never run here: they are guarded to repositories rendered from the blueprint.

To add a component, see [docs/adding-a-component.md](docs/adding-a-component.md).

## Carrying blueprint changes to tenants

A rendered repository does not track the blueprint. To bring a change across, render the
new blueprint with the tenant's `init.env` into a scratch directory and compare it with
the tenant repository; carry over what applies, as a reviewed pull request.

## Licence

Apache-2.0, see [LICENSE](LICENSE). A rendered tenant repository is private and carries
no licence.
