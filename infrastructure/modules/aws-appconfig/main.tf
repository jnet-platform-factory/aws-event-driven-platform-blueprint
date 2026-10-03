###############################################################################
# AWS AppConfig feature flags
# One application per account, with one feature-flag configuration profile and
# one environment named after the stage, and a deployment strategy tuned per
# stage (immediate in dev, gradual in production).
#
# Every environment has its own account, so nothing here is shared between
# stages and every stack owns all of its resources. The identifiers are
# published by platform-resources under /platform/<env>/appconfig_*.
###############################################################################

resource "aws_appconfig_application" "this" {
  name        = var.application_name
  description = "Feature flags for ${var.application_name}"

  tags = var.tags
}

resource "aws_appconfig_configuration_profile" "this" {
  application_id = aws_appconfig_application.this.id
  name           = var.application_name
  location_uri   = "hosted"
  type           = "AWS.AppConfig.FeatureFlags"
  description    = "Feature flags for ${var.application_name}"

  tags = var.tags
}

resource "aws_appconfig_environment" "this" {
  name           = var.environment
  application_id = aws_appconfig_application.this.id
  description    = "${var.application_name} ${var.environment}"

  tags = var.tags
}

resource "aws_appconfig_deployment_strategy" "this" {
  name                           = "${var.application_name}-${var.environment}"
  description                    = "Feature flag rollout in ${var.environment}"
  deployment_duration_in_minutes = var.deployment_duration_minutes
  growth_factor                  = var.growth_factor
  growth_type                    = var.growth_type
  final_bake_time_in_minutes     = var.bake_time_minutes
  replicate_to                   = "NONE"

  tags = var.tags
}
