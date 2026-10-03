output "logs_bucket_id" {
  description = "Name of the logs bucket"
  value       = module.logs_bucket.s3_bucket_id
}

output "logs_bucket_arn" {
  description = "ARN of the logs bucket"
  value       = module.logs_bucket.s3_bucket_arn
}

output "ssm_parameter_names" {
  description = "Every SSM parameter published, by key"
  value       = { for k, v in aws_ssm_parameter.params : k => v.name }
}
