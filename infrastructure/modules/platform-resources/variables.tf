variable "name" {
  description = "Prefix for the logs bucket, e.g. <prefix>-<env>"
  type        = string
}

variable "environment" {
  description = "The stage (dev, production); namespaces the SSM parameters"
  type        = string
}

variable "account_alias" {
  description = "IAM account alias (globally unique). Empty: leave the alias alone"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Days the logs bucket keeps an object"
  type        = number
  default     = 365
}

variable "ssm_parameters" {
  description = "key => value, published as String parameters under /platform/<environment>/<key>"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
