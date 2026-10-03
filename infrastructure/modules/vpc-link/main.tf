###############################################################################
# VPC Link
# An HTTP API (API Gateway v2) VPC Link into the private subnets, for SAM
# applications with private integrations. Its ID is published to SSM by
# platform-resources.
###############################################################################

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = var.name
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  tags = merge(var.tags, {
    Name = var.name
  })
}
