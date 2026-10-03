include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//acm"
}

# The certificate only validates once the zone is delegated from its parent
# domain: apply route53, delegate it, then apply this.
dependency "route53" {
  config_path = "../route53"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    zone_id = "Z00000000000000000000"
  }
}

inputs = {
  domain_name               = include.root.locals.settings.domain_name
  subject_alternative_names = ["*.${include.root.locals.settings.domain_name}"]
  zone_id                   = dependency.route53.outputs.zone_id
}
