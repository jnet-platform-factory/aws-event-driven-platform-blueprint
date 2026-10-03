# **PLATFORM_REPO**

**TENANT**'s platform: its AWS accounts' configuration and every deploy into them.
The tools are public, in [jnet-platform-factory](https://github.com/jnet-platform-factory),
and pinned here by tag or commit; this repository holds only **TENANT**'s
configuration and the pipelines that apply it. It was rendered from
[platform-blueprint](https://github.com/jnet-platform-factory/platform-blueprint) — the
platform model, and the rules every pipeline follows, are in [PLATFORM.md](PLATFORM.md).

| Environment  | AWS account                 | aws-vault profile        | Regions                               |
| ------------ | --------------------------- | ------------------------ | ------------------------------------- |
| `dev`        | `__DEV_ACCOUNT_ID__`        | `__DEV_PROFILE__`        | `__PRIMARY_REGION__`, `__EO_REGION__` |
| `production` | `__PRODUCTION_ACCOUNT_ID__` | `__PRODUCTION_PROFILE__` | `__PRIMARY_REGION__`, `__EO_REGION__` |

Components: `__COMPONENTS__`.

## Filling in

`make ready` lists every `CHANGEME` left: domains, addresses, the OpenSearch domain.
Every target that reaches AWS runs it first, so nothing deploys a placeholder.

## First deploy, in order

1. **Bootstrap each account**, by hand, with admin credentials —
   [aws-account-bootstrap/README.md](aws-account-bootstrap/README.md): `make apply`, then
   `make ci-roles`, for `dev` and then `production`. This creates the deploy roles and
   the `dev` / `production` GitHub environments with their `AWS_*` variables.
2. **Protect the GitHub environments**: required reviewers and `main` only on
   `production`, `bootstrap-production` and `eo-production`; the same for
   `bootstrap-dev` and `eo-dev` if dev changes need a second pair of eyes.
3. **Add the `CICD_ACCESS_TOKEN` secret** (read access to the repositories' OIDC
   settings, push for Create Release).

<!-- infrastructure -->

4. **Infrastructure** — [infrastructure/README.md](infrastructure/README.md): create the
   state bucket, apply `route53`, delegate the zone, then the rest. It publishes the SSM
   bridge every application reads.

<!-- /infrastructure -->

5. **Everything else** deploys from its workflow on merge to `main`: dev first, then
   production behind its reviewers.

## Pipelines

Every deploy is a CloudFormation change set or a Terraform plan that someone reads
before it runs. A pull request shows it in dev; a merge to `main` applies dev, then waits
for the production reviewers.

| Workflow                          | What it deploys                                      | Credentials             |
| --------------------------------- | ---------------------------------------------------- | ----------------------- |
| `check.yml`                       | nothing: every gate that needs no AWS                | none                    |
| `aws-account-bootstrap.yml`       | the deploy roles (plan, analyze, diff weekly; apply) | `ci-roles/`             |
| `infrastructure.yml`              | `infrastructure/live`                                | `AWS_PLATFORM_ROLE_ARN` |
| `ssm-parameters.yml`              | `ssm-parameters/ssm-parameters.json`                 | `AWS_PLATFORM_ROLE_ARN` |
| `events-observability.yml`        | the SAR forwarder                                    | `ci-roles/` (eo)        |
| `aws-daily-monitoring-report.yml` | the daily report                                     | `AWS_APP_ROLE_ARN`      |
| `platform-api.yml`                | `GET /platform/info`                                 | `AWS_APP_ROLE_ARN`      |
| `lambda-layer.yml`                | the base Lambda layer                                | `AWS_APP_ROLE_ARN`      |
| `release-tag-create.yml`          | a release tag and `release/<tag>` branch             | `CICD_ACCESS_TOKEN`     |

`make check` runs every gate locally; each component's own Makefile has the targets that
reach AWS (`make help` in its directory).
