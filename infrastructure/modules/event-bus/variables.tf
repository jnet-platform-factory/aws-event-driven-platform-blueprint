variable "name" {
  description = "Name of the event bus, e.g. <prefix>-events-<env>"
  type        = string
}

variable "environment" {
  description = "The stage (dev, production); namespaces the SSM parameters"
  type        = string
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
