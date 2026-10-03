###############################################################################
# Event bus
# The tenant's EventBridge bus, owned by the platform. Every producer publishes
# to it, and events-observability is one consumer: its stack references the bus
# by name and never owns it, so deleting or replacing that stack cannot delete
# the bus every producer depends on.
#
# The name and ARN are published to SSM in the bus's own region, under
# /platform/<env>/event_bus_name and /platform/<env>/event_bus_arn.
###############################################################################

resource "aws_cloudwatch_event_bus" "this" {
  name = var.name

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssm_parameter" "name" {
  name        = "/platform/${var.environment}/event_bus_name"
  description = "The platform event bus"
  type        = "String"
  value       = aws_cloudwatch_event_bus.this.name

  tags = var.tags
}

resource "aws_ssm_parameter" "arn" {
  name        = "/platform/${var.environment}/event_bus_arn"
  description = "The platform event bus"
  type        = "String"
  value       = aws_cloudwatch_event_bus.this.arn

  tags = var.tags
}
