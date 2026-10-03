###############################################################################
# Route 53 public hosted zone
# One zone per environment, in that environment's account. Delegate it from the
# parent domain with an NS record set of name_servers (see the README).
###############################################################################

resource "aws_route53_zone" "this" {
  name    = var.domain_name
  comment = "${var.domain_name}, managed by Terraform"

  tags = merge(var.tags, {
    Name = var.domain_name
  })
}
