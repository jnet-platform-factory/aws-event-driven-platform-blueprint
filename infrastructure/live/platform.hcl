# What differs between __TENANT__'s environments. Every unit under live/ reads
# this through root.hcl (include.root.locals.settings); the unit files themselves
# are the same in every environment.
#
# Replace every placeholder below before the first plan: `make -C infrastructure
# ready` refuses to run Terragrunt while one is left.
locals {
  application = "__TENANT__"
  prefix      = "__PREFIX__"

  environments = {
    dev = {
      # Non-overlapping ranges, so the VPCs can be peered or routed later.
      vpc_cidr           = "10.0.0.0/16"
      public_subnets     = ["10.0.0.0/24", "10.0.1.0/24"]
      private_subnets    = ["10.0.100.0/24", "10.0.101.0/24"]
      azs                = [] # empty: the region's first zones
      enable_nat_gateway = true

      # The hosted zone this environment's APIs are served from. Delegate it
      # from its parent domain after the route53 unit's first apply.
      domain_name = "dev.CHANGEME.example.com"

      # Globally unique. Empty: leave the account's alias alone.
      account_alias = "__PREFIX__-dev"

      # Feature flags roll out at once in dev.
      appconfig = {
        deployment_duration_minutes = 0
        growth_factor               = 100
        bake_time_minutes           = 0
      }
    }

    production = {
      vpc_cidr           = "10.1.0.0/16"
      public_subnets     = ["10.1.0.0/24", "10.1.1.0/24"]
      private_subnets    = ["10.1.100.0/24", "10.1.101.0/24"]
      azs                = []
      enable_nat_gateway = true

      domain_name = "CHANGEME.example.com"

      account_alias = "__PREFIX__-production"

      # Gradually in production: 20% every 2 minutes, then 5 minutes watching alarms.
      appconfig = {
        deployment_duration_minutes = 10
        growth_factor               = 20
        bake_time_minutes           = 5
      }
    }
  }
}
