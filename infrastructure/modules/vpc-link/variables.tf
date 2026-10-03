variable "name" {
  description = "Name of the VPC Link"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs the VPC Link reaches"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups of the VPC Link"
  type        = list(string)
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
