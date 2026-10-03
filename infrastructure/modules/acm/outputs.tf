output "certificate_arn" {
  description = "Certificate ARN, once validated; for API Gateway custom domains"
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "certificate_domain_name" {
  description = "Primary domain of the certificate"
  value       = aws_acm_certificate.this.domain_name
}
