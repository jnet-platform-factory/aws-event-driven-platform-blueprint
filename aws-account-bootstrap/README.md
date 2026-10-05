# aws-account-bootstrap

**TENANT**'s configuration for the public
[aws-account-bootstrap](https://github.com/jnet-platform-factory/aws-account-bootstrap):
the GitHub OIDC provider and the keyless deploy roles in each AWS account. No tool
code lives here — the [Makefile](Makefile) clones the tool at a pinned commit into
`.tool/<sha>/` and runs it against `configs/<account>.env`.

| Account      | Config                                           | Creates                                                                                               |
| ------------ | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `dev`        | [configs/dev.env](configs/dev.env)               | `platform-deploy-role` (Terraform), `app-deploy-role` + `app-cfn-exec-role` (SAM), `lambda-test-role` |
| `production` | [configs/production.env](configs/production.env) | the same                                                                                              |

`apply` also creates the GitHub environment of the same name (`dev`, `production`) in
every repository the config lists, and sets `AWS_ACCOUNT_ID`, `AWS_REGION`,
`AWS_PLATFORM_ROLE_ARN`, `AWS_APP_ROLE_ARN` and `AWS_CFN_EXEC_ROLE_ARN` in it. Every
workflow in this repository reads its role from those variables.

## Commands

```bash
cd aws-account-bootstrap
make check                    # pin, configs, scripts, CI roles template; no AWS
make plan    ACCOUNT=dev      # renders every document; changes nothing
make analyze ACCOUNT=dev      # Access Analyzer + IAM simulator (the tool's `check`); read-only
make diff    ACCOUNT=dev      # rendered documents against live IAM; exit 1 on drift
make apply   ACCOUNT=dev      # a human with admin the first time; then CI, behind a reviewer
make verify-pin               # the tag still points at the pinned commit
make sso-plan                 # Identity Center, in the management account; read-only
make sso-apply                # create / update its permission sets, groups and assignments
```

`ACCOUNT` picks the config and the aws-vault profile (`PROFILE_<account>` in the
Makefile). Run `gh auth status` right before a plan or apply: the trust policies are
rendered from each repository's OIDC subject setting, which the tool reads with `gh`,
and `make github-oidc` refuses to go on when it cannot.

## First, once per organisation: Identity Center

People sign in to every account through IAM Identity Center, which lives in the
organisation's management account. `make sso-plan` and `make sso-apply` run the tool's
`identity-center.sh` there, under the management profile (`PROFILE_management` in the
Makefile, from `MANAGEMENT_PROFILE`): the permission sets, the groups and which group
gets which permission set in which account. The group files name accounts by their name
in AWS Organizations or by OU (`Workloads/NonProd`, `Workloads/Prod`), so the accounts
and OUs must exist first. Re-running changes nothing that already matches; it never
deletes or removes anything. The management account gets no deploy roles and no config
here, and these targets are a human's, never CI's.

## First time in an account

1. **Apply by hand**, with admin credentials: `make apply ACCOUNT=dev`. The roles CI
   would use do not exist yet.
2. **Deploy the CI roles**, by hand: `make ci-roles ACCOUNT=dev`. They are what this
   repository's own pipelines assume for the bootstrap itself (`bootstrap-<account>-plan`,
   `bootstrap-<account>`) and for events-observability (`eo-<account>-plan`,
   `eo-<account>`). They are kept out of the bootstrap on purpose: an apply that goes
   wrong must not take away the pipeline that would fix it.
3. **Create the GitHub environments** the CI roles trust, and protect them:

   | Environment                | Protection                      |
   | -------------------------- | ------------------------------- |
   | `dev`                      | none (pull requests plan here)  |
   | `production`               | required reviewers, `main` only |
   | `bootstrap-<account>-plan` | none                            |
   | `bootstrap-<account>`      | required reviewers, `main` only |
   | `eo-<account>-plan`        | none                            |
   | `eo-<account>`             | required reviewers, `main` only |

4. **Create the Terraform state bucket** (see [../infrastructure/README.md](../infrastructure/README.md)),
   name it in `STATE_BUCKETS`, and apply again so no deploy role can delete it.

From then on [.github/workflows/aws-account-bootstrap.yml](../.github/workflows/aws-account-bootstrap.yml)
plans, checks and diffs both accounts on every pull request and every Monday, and
applies on demand behind the `bootstrap-<account>` reviewer.

## Rules

- **Never rename a role or policy in place.** The guardrails are rendered with the
  names, so a rename leaves the old resources unprotected and unmanaged. Choose every
  name before the first apply.
- **Two configs for one AWS account must agree** — every run rewrites each trust policy
  from one config alone. `make same-account` enforces it, grouping the configs by the
  account named on their first line.
- **`NO_APPLY`** in the Makefile lists accounts whose apply is refused at this pin.
  Use it when a plan shows a change you have not decided to make.
- **Moving the pin**: change `TOOL_TAG` and `TOOL_REF` together, after reading the
  tool's changes and running `make plan` and `make diff` against every account.
