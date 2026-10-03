# infrastructure

**TENANT**'s Terragrunt foundation: one VPC, its security groups and API Gateway VPC
Link, a hosted zone and certificate, AppConfig feature flags, the tenant's event bus,
a logs bucket, and the **SSM bridge** that hands all of it to SAM applications.

```
live/root.hcl          accounts, state, provider — one file, every unit includes it
live/platform.hcl      what differs between environments: CIDRs, domain, rollout
live/<env>/<region>/<component>/terragrunt.hcl
modules/<component>/   plain Terraform, one module per component
```

The directory picks the account: everything under `live/dev/` goes to the dev account,
and the unit files are the same in every environment — only `platform.hcl` differs.
State is one bucket per account, in the account, keyed by the unit's path, with S3
lockfiles (no DynamoDB table).

## Units

| Unit                 | Region               | Depends on           | Publishes                                   |
| -------------------- | -------------------- | -------------------- | ------------------------------------------- |
| `vpc`                | `__PRIMARY_REGION__` |                      | subnets                                     |
| `security-groups`    | `__PRIMARY_REGION__` | vpc                  | Lambda and VPC Link groups                  |
| `vpc-link`           | `__PRIMARY_REGION__` | vpc, security-groups |                                             |
| `route53`            | `__PRIMARY_REGION__` |                      | the zone's name servers, to delegate        |
| `acm`                | `__PRIMARY_REGION__` | route53 (delegated)  |                                             |
| `aws-appconfig`      | `__PRIMARY_REGION__` |                      |                                             |
| `platform-resources` | `__PRIMARY_REGION__` | all of the above     | `/platform/<env>/*` in SSM, the logs bucket |
| `event-bus`          | `__EO_REGION__`      |                      | `/platform/<env>/event_bus_*` in its region |

## The SSM bridge

`platform-resources` publishes every value an application needs as a **String**
parameter under `/platform/<env>/`:

`vpc_id`, `private_subnet_ids`, `public_subnet_ids`, `lambda_security_group_id`,
`vpc_link_security_group_id`, `vpc_link_id`, `hosted_zone_id`, `domain_name`,
`certificate_arn`, `appconfig_application_id`, `appconfig_environment_id`,
`appconfig_configuration_profile_id`, `logs_bucket`.

A SAM template reads them as `AWS::SSM::Parameter::Value<String>` parameters (see
[../platform-api/template.yaml](../platform-api/template.yaml)) or with
`{{resolve:ssm:/platform/<env>/<key>}}`. String, never SecureString: CloudFormation can
resolve a SecureString in neither position. Secrets go through
[../ssm-parameters](../ssm-parameters) instead.

## First time in an environment

1. **Fill in** [live/platform.hcl](live/platform.hcl): every `CHANGEME`, and the CIDRs if
   the defaults collide with a network you will connect to.
2. **Create the state bucket**, by hand, with admin credentials:
   `make state-bucket ENV=dev`. It is already named in the bootstrap config's
   `STATE_BUCKETS`, so no deploy role can delete it.
3. **Plan, then apply** `route53` alone, and **delegate the zone**: add an NS record set
   for `domain_name` in its parent domain with the zone's `name_servers`. `acm` waits for
   the delegation to validate.
4. **Plan and apply the rest**: `make plan ENV=dev`, then `make apply ENV=dev` — or merge,
   and let [the workflow](../.github/workflows/infrastructure.yml) do it.

## Rules

- **Additive, or it is an outage.** Never rename a live name (a VPC, a bucket, a bus) in
  place: Terraform replaces it. Read every plan for `must be replaced`.
- **`no_apply`** in [live/root.hcl](live/root.hcl) lists units whose apply is refused, for
  adopting resources that already exist: import them, plan until clean, then take the
  unit out of the list in a reviewed change.
- **The event bus is the platform's.** It has `prevent_destroy`; producers and
  events-observability reference it by name.
