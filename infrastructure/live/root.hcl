# Root Terragrunt config for __TENANT__, deploying with platform-deploy-role.
# Based on aws-account-bootstrap's templates/root.hcl (v0.0.3, unchanged to v0.0.6); keep the two close,
# so a newer template can be compared with this file.
#
# Layout:
#
#   infrastructure/live/root.hcl                                    this file
#   infrastructure/live/platform.hcl                                the per-environment settings
#   infrastructure/live/<env>/<region>/<component>/terragrunt.hcl   one unit per component
#                                                                   ("global" as the region means us-east-1)
#
# A unit only needs to include this file:
#
#   include "root" {
#     path   = find_in_parent_folders("root.hcl")
#     expose = true                     # include.root.locals.env, .settings, .modules ...
#   }
#   terraform { source = "${include.root.locals.modules}//vpc" }
#   inputs    = { name = "${include.root.locals.name}" }
#
# The directory picks the account: everything under live/dev/ goes to the dev
# account, and switching to another account is `cd`. An environment missing from
# local.accounts, or a unit outside the layout, fails here rather than applying
# somewhere unintended.
#
# Credentials, with no assume-role chain — each account is reached directly:
#   - In GitHub Actions the job has already assumed vars.AWS_PLATFORM_ROLE_ARN in the
#     GitHub environment of the same name. Those credentials are used as they are.
#   - On your machine the environment's profile below is used, so one
#     `aws sso login --profile <profile>` and you can run terragrunt anywhere under its
#     directory. Credentials already exported (aws-vault exec, AWS_ACCESS_KEY_ID) win.
#   Either way allowed_account_ids refuses to touch any other account.
locals {
  # One entry per GitHub environment the bootstrap was run with.
  accounts = {
    dev = {
      account_id   = "__DEV_ACCOUNT_ID__"
      profile      = "__DEV_PROFILE__"
      region       = "__PRIMARY_REGION__"
      state_bucket = "__PREFIX__-terraform-state-__DEV_ACCOUNT_ID__"
    }
    production = {
      account_id   = "__PRODUCTION_ACCOUNT_ID__"
      profile      = "__PRODUCTION_PROFILE__"
      region       = "__PRIMARY_REGION__"
      state_bucket = "__PREFIX__-terraform-state-__PRODUCTION_ACCOUNT_ID__"
    }
  }

  # <env>/<region>/<component>, relative to this file. No try(): a unit outside this
  # shape is an error, not a guess. The component may contain anything, "_" too.
  parts      = regex("^([^/]+)/([^/]+)/(.+)$", path_relative_to_include())
  env        = local.parts[0]
  region     = local.parts[1] == "global" ? "us-east-1" : local.parts[1]
  component  = local.parts[2]
  account    = local.accounts[local.env]
  account_id = local.account.account_id

  # platform.hcl: what differs between environments. Units read local.settings.
  platform    = read_terragrunt_config("${get_parent_terragrunt_dir()}/platform.hcl").locals
  application = local.platform.application
  prefix      = local.platform.prefix
  settings    = local.platform.environments[local.env]
  name        = "${local.prefix}-${local.env}"
  modules     = "${get_parent_terragrunt_dir()}/../modules"

  # Units listed here refuse apply and destroy. Use it while adopting live
  # resources: a unit leaves the list in a reviewed change, once its plan is clean.
  no_apply = []

  # The environment's profile, unless credentials are already in the environment.
  ambient = get_env("GITHUB_ACTIONS", "") == "true" || get_env("AWS_ACCESS_KEY_ID", "") != ""
  profile = local.ambient ? null : local.account.profile
}

terraform {
  before_hook "no_apply" {
    commands = contains(local.no_apply, path_relative_to_include()) ? ["apply", "destroy"] : []
    execute  = ["sh", "-c", "echo '${path_relative_to_include()} is in no_apply in infrastructure/live/root.hcl' >&2; exit 1"]
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = merge(
    {
      # One bucket per account, in the account: its state never leaves it and no
      # cross-account bucket policy is needed. Create each once, by hand
      # (terragrunt --backend-bootstrap, never in CI), and add it to that account's
      # STATE_BUCKETS so no deploy role can delete it or switch off versioning.
      bucket       = local.account.state_bucket
      key          = "${path_relative_to_include()}/terraform.tfstate" # the layout is the key
      region       = local.account.region
      encrypt      = true
      use_lockfile = true # Terraform 1.10+: no DynamoDB lock table
    },
    local.profile == null ? {} : { profile = local.profile },
  )
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.region}"
      %{if local.profile != null}profile = "${local.profile}"%{endif}

      # A run with the wrong credentials fails here, before it changes anything.
      allowed_account_ids = ["${local.account_id}"]

      default_tags {
        tags = {
          Application = "${local.application}"
          Environment = "${local.env}"
          Component   = "${local.component}"
          ManagedBy   = "terragrunt"
        }
      }
    }
  EOF
}
