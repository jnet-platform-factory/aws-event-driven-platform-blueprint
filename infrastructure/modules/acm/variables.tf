variable "domain_name" {
  description = "Primary domain of the certificate, e.g. api.example.com"
  type        = string
}

variable "subject_alternative_names" {
  description = "Other names on the certificate, e.g. [\"*.api.example.com\"]"
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route 53 hosted zone for the DNS validation records"
  type        = string
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
