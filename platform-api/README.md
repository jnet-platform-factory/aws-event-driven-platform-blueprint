# platform-api

One endpoint, `GET /platform/info`, that returns the infrastructure configuration
`infrastructure/` published to SSM under `/platform/<stage>/`. It is the proof that the
SSM bridge works end to end, and the pattern every SAM application of **TENANT**'s
copies:

- **Infrastructure values arrive as `AWS::SSM::Parameter::Value<String>` parameters**,
  resolved at deploy time. Their paths are in `deployments/<stage>.json`, so the
  template never names a stage, and a missing parameter fails the change set before
  anything is deployed.
- **The function needs no SSM permissions**: the values are environment variables.
- **The deploy is a change set**, built with `sam build`, packaged into the account's SAM
  CLI bucket, and created through [../bin/cfn-changeset](../bin/cfn-changeset) with the
  bootstrap's `app-cfn-exec-role`.

| Stage        | Stack                     | Account / region                  |
| ------------ | ------------------------- | --------------------------------- |
| `dev`        | `__PREFIX__-platform-api` | dev / `__PRIMARY_REGION__`        |
| `production` | `__PREFIX__-platform-api` | production / `__PRIMARY_REGION__` |

```bash
make check                                    # tests, sam validate, parameter files; no AWS
make changeset STAGE=dev                      # executes nothing
make execute   STAGE=dev CHANGE_SET=<name>    # after reading it
```

Deploy it after `infrastructure/`'s `platform-resources` unit: until the `/platform/<stage>/*`
parameters exist, the change set fails. A new endpoint is a new `HttpApi` event on a
function; a new value from Terraform is a key in `platform-resources`' `ssm_parameters`,
a parameter here, and a line in both deployment records.
