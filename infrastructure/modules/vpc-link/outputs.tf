output "vpc_link_id" {
  description = "VPC Link ID; SAM templates read it from /platform/<env>/vpc_link_id"
  value       = aws_apigatewayv2_vpc_link.this.id
}

output "vpc_link_arn" {
  description = "VPC Link ARN"
  value       = aws_apigatewayv2_vpc_link.this.arn
}
