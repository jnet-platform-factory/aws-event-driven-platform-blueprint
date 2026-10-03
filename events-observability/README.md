# events-observability

**TENANT**'s deployment of
[aws-eventbridge-firehose-opensearch-forwarder](https://github.com/jnet-platform-factory/aws-eventbridge-firehose-opensearch-forwarder),
from the Serverless Application Repository (SAR): an EventBridge rule on the tenant's
event bus, delivery to OpenSearch through Firehose, and an SQS → SNS error digest.

![Publish once to SAR, deploy per tenant](../docs/sar-deploy-flow.svg)

| Stage        | Stack                                        | Account / region             | Record                                                     |
| ------------ | -------------------------------------------- | ---------------------------- | ---------------------------------------------------------- |
| `dev`        | `__PREFIX__-events-observability-dev`        | dev / `__EO_REGION__`        | [deployments/dev.json](deployments/dev.json)               |
| `production` | `__PREFIX__-events-observability-production` | production / `__EO_REGION__` | [deployments/production.json](deployments/production.json) |

## Files

- **`deployments/<stage>.json`** — the stack's complete parameter set, in
  `create-change-set --parameters` form. Every parameter the pinned template declares
  is listed, empty ones too: one left out would take the template's default, which
  need not be what is live. `make check` enforces it.
- **`tenants/tenant.json`** — the `ShapingConfig` field map in readable form. Each
  record's `ShapingConfig` must be exactly `jq -c . tenants/tenant.json`.
- **`bin/changeset`** — asks SAR for the pinned version's template, then creates the
  change set through [../bin/cfn-changeset](../bin/cfn-changeset) with the CloudFormation
  service role `__PREFIX__-platform-eo-cfn-exec`.

## Filling in

Before the first change set, replace every `CHANGEME` in both records:

- `OpenSearchEndpoint` and `OpenSearchResourceArn` — the domain events are sent to.
  A domain in another account must allow this stack's forwarder role.
- `AlertEmail` — where the error digest goes.

`EventBusName` names the bus `infrastructure/` creates (`__PREFIX__-events-<stage>`).
**The bus belongs to the platform, not to this stack**: if the stack owned it, deleting
or replacing the stack would delete every producer's bus. Leave `EventBusName` empty
only if you deliberately want the stack to create its own bus.

## Deploying

```bash
make check                                    # no AWS
make changeset STAGE=dev                      # a change set to read; executes nothing
make execute   STAGE=dev CHANGE_SET=<name>    # after reading it
```

In CI ([.github/workflows/events-observability.yml](../.github/workflows/events-observability.yml)):
a pull request creates a change set in each stage and deletes it again, so its effect
is in the run summary; a merge to `main` creates them again and waits for the
`eo-<stage>` reviewer to execute each one.

Any Remove or Replacement fails the change set unless `ALLOW_DESTRUCTIVE=1` is set
deliberately.

## Moving the pin

SAR versions are immutable, so a version that is published is never changed. To
move: read the product's changes, set `SAR_VERSION` in the [Makefile](Makefile), add or
remove parameters in both records as `make check` asks, and read each change set.
The application must be shared with this tenant's accounts in `__EO_REGION__` by its
publisher before a change set can be created.
