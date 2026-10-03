include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//platform-resources"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    public_subnet_ids  = ["subnet-00000000000000003", "subnet-00000000000000004"]
  }
}

dependency "security_groups" {
  config_path = "../security-groups"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    lambda_security_group_id   = "sg-00000000000000001"
    vpc_link_security_group_id = "sg-00000000000000002"
  }
}

dependency "vpc_link" {
  config_path = "../vpc-link"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_link_id = "vpclink-mock"
  }
}

dependency "route53" {
  config_path = "../route53"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    zone_id     = "Z00000000000000000000"
    domain_name = "mock.example.com"
  }
}

dependency "acm" {
  config_path = "../acm"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:000000000000:certificate/mock"
  }
}

dependency "appconfig" {
  config_path = "../aws-appconfig"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    application_id           = "mock"
    environment_id           = "mock"
    configuration_profile_id = "mock"
  }
}

inputs = {
  name          = include.root.locals.name
  environment   = include.root.locals.env
  account_alias = include.root.locals.settings.account_alias

  # The SSM bridge: /platform/<env>/<key>, read by every SAM application.
  ssm_parameters = {
    vpc_id                             = dependency.vpc.outputs.vpc_id
    private_subnet_ids                 = join(",", dependency.vpc.outputs.private_subnet_ids)
    public_subnet_ids                  = join(",", dependency.vpc.outputs.public_subnet_ids)
    lambda_security_group_id           = dependency.security_groups.outputs.lambda_security_group_id
    vpc_link_security_group_id         = dependency.security_groups.outputs.vpc_link_security_group_id
    vpc_link_id                        = dependency.vpc_link.outputs.vpc_link_id
    hosted_zone_id                     = dependency.route53.outputs.zone_id
    domain_name                        = dependency.route53.outputs.domain_name
    certificate_arn                    = dependency.acm.outputs.certificate_arn
    appconfig_application_id           = dependency.appconfig.outputs.application_id
    appconfig_environment_id           = dependency.appconfig.outputs.environment_id
    appconfig_configuration_profile_id = dependency.appconfig.outputs.configuration_profile_id
  }
}
