# aws-daily-monitoring-report

**TENANT**'s deployment of the public
[aws-daily-monitoring-report](https://github.com/jnet-platform-factory/aws-daily-monitoring-report):
a scheduled Lambda that emails one account's health and cost report every day and,
optionally, writes a JSON snapshot to an S3 bucket.

| Stage        | Stack                         | Account / region                  | Record                                                     |
| ------------ | ----------------------------- | --------------------------------- | ---------------------------------------------------------- |
| `dev`        | `aws-daily-monitoring-report` | dev / `__PRIMARY_REGION__`        | [deployments/dev.json](deployments/dev.json)               |
| `production` | `aws-daily-monitoring-report` | production / `__PRIMARY_REGION__` | [deployments/production.json](deployments/production.json) |

The tool has no tags, so the [Makefile](Makefile) pins it by commit (`TOOL_REF`),
builds that checkout with `sam build`, packages it into the account's SAM CLI bucket
and creates the change set through [../bin/cfn-changeset](../bin/cfn-changeset) with the
bootstrap's `app-cfn-exec-role`.

## Filling in

In both records, set `RecipientEmail` and `SenderEmail` (the sender must be an SES
verified identity in the account) and replace the `CHANGEME` values. To also write a
snapshot, set `SnapshotBucket`; the slug must stay `__PREFIX__-<stage>` so no two
stacks ever write the same object (`make check` enforces it).

## Deploying

```bash
make check                                    # no AWS
make changeset STAGE=dev                      # build, package, change set; executes nothing
make execute   STAGE=dev CHANGE_SET=<name>    # after reading it
make invoke    STAGE=dev                      # send a report now (a human, never CI)
```

In CI ([.github/workflows/aws-daily-monitoring-report.yml](../.github/workflows/aws-daily-monitoring-report.yml)):
a pull request creates a dev change set and deletes it again; a merge to `main`
executes dev, then creates the production change set and executes it behind the
`production` environment's reviewers.

## Rules

- **The function name is an identity.** The template names the function
  `aws-daily-monitoring-report`; changing `FunctionNameSuffix` under a live stack
  replaces the Lambda. `make check` keeps it empty.
- **Moving the pin**: `make verify-pin` says how far behind the tool's `main` the pin
  is. Move `TOOL_REF` after reading the tool's changes, and read the change set.
