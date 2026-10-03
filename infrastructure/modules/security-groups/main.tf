###############################################################################
# Security groups
# - functions: all egress, and ingress from the VPC Link only
# - VPC Link: HTTPS in from API Gateway, out to the functions only
###############################################################################

resource "aws_security_group" "lambda" {
  name_prefix = "${var.name}-lambda-"
  description = "Lambda functions in the platform VPC"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-lambda"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_all_outbound" {
  security_group_id = aws_security_group.lambda.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "lambda_from_vpc_link" {
  security_group_id            = aws_security_group.lambda.id
  description                  = "From the API Gateway VPC Link"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.vpc_link.id
}

resource "aws_security_group" "vpc_link" {
  name_prefix = "${var.name}-vpc-link-"
  description = "API Gateway VPC Link"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-link"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_link_https" {
  security_group_id = aws_security_group.vpc_link.id
  description       = "HTTPS from API Gateway"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_lambda" {
  security_group_id            = aws_security_group.vpc_link.id
  description                  = "To the Lambda security group"
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.lambda.id
}
