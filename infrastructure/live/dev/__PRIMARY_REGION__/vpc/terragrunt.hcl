include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//vpc"
}

inputs = {
  name               = include.root.locals.name
  vpc_cidr           = include.root.locals.settings.vpc_cidr
  public_subnets     = include.root.locals.settings.public_subnets
  private_subnets    = include.root.locals.settings.private_subnets
  azs                = include.root.locals.settings.azs
  enable_nat_gateway = include.root.locals.settings.enable_nat_gateway
}
