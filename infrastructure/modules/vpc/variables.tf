variable "name" {
  description = "Name of the VPC; prefixes every resource's Name tag"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "azs" {
  description = "Availability zones, one per subnet pair. Empty: the region's first zones, as many as there are subnets"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "Public subnet CIDRs, one per availability zone"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs, one per availability zone"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "One NAT gateway for the private subnets' internet access. Off saves its hourly cost when nothing private needs the internet"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
