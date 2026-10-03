include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${include.root.locals.modules}//aws-appconfig"
}

inputs = {
  application_name            = "${include.root.locals.prefix}-platform"
  environment                 = include.root.locals.env
  deployment_duration_minutes = include.root.locals.settings.appconfig.deployment_duration_minutes
  growth_factor               = include.root.locals.settings.appconfig.growth_factor
  bake_time_minutes           = include.root.locals.settings.appconfig.bake_time_minutes
}
