include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//vpc-link"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
  }
}

dependency "security_groups" {
  config_path = "../security-groups"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_link_security_group_id = "sg-00000000000000000"
  }
}

inputs = {
  name               = include.root.locals.name
  subnet_ids         = dependency.vpc.outputs.private_subnet_ids
  security_group_ids = [dependency.security_groups.outputs.vpc_link_security_group_id]
}
