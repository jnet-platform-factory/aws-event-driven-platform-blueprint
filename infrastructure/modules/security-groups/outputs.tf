output "lambda_security_group_id" {
  description = "Security group for Lambda functions in the VPC"
  value       = aws_security_group.lambda.id
}

output "vpc_link_security_group_id" {
  description = "Security group for the API Gateway VPC Link"
  value       = aws_security_group.vpc_link.id
}
