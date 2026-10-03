variable "domain_name" {
  description = "Domain of the hosted zone, e.g. api.example.com"
  type        = string
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
