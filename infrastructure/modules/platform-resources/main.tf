###############################################################################
# Platform resources
# - the account alias
# - a logs bucket (ELB, ALB and S3 access logs)
# - the SSM bridge: every value SAM applications need from Terraform, published
#   as String parameters under /platform/<env>/<key>
#
# String, never SecureString: CloudFormation resolves a String through
# {{resolve:ssm:...}} or an AWS::SSM::Parameter::Value<String> parameter, and a
# SecureString in neither position. Nothing published here is a secret.
###############################################################################

data "aws_caller_identity" "current" {}

resource "aws_iam_account_alias" "this" {
  count         = var.account_alias == "" ? 0 : 1
  account_alias = var.account_alias
}

module "logs_bucket" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-s3-bucket.git?ref=v4.2.0"

  # Bucket names are global: the account id makes it unique.
  bucket        = lower("${var.name}-logs-${data.aws_caller_identity.current.account_id}")
  force_destroy = false

  control_object_ownership = true
  object_ownership         = "ObjectWriter"

  attach_access_log_delivery_policy = true
  attach_elb_log_delivery_policy    = true
  attach_lb_log_delivery_policy     = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  lifecycle_rule = [
    {
      id      = "expire-old-logs"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 90
          storage_class = "GLACIER"
        }
      ]

      expiration = {
        days = var.log_retention_days
      }

      noncurrent_version_expiration = {
        days = 30
      }
    }
  ]

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = var.tags
}

resource "aws_ssm_parameter" "params" {
  for_each = merge(var.ssm_parameters, {
    logs_bucket = module.logs_bucket.s3_bucket_id
  })

  name        = "/platform/${var.environment}/${each.key}"
  description = "Platform parameter ${each.key}, written by Terraform"
  type        = "String"
  value       = each.value

  tags = var.tags
}
