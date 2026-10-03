include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//security-groups"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
}

inputs = {
  name   = include.root.locals.name
  vpc_id = dependency.vpc.outputs.vpc_id
}
