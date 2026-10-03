include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//route53"
}

inputs = {
  domain_name = include.root.locals.settings.domain_name
}
