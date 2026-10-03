output "zone_id" {
  description = "Hosted zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "Name servers to delegate the zone to from its parent domain"
  value       = aws_route53_zone.this.name_servers
}

output "domain_name" {
  description = "Domain of the hosted zone"
  value       = aws_route53_zone.this.name
}
