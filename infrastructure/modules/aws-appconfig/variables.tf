variable "application_name" {
  description = "AppConfig application name; also names the configuration profile"
  type        = string
}

variable "environment" {
  description = "AppConfig environment name: the stage (dev, production)"
  type        = string
}

variable "deployment_duration_minutes" {
  description = "Minutes a flag deployment takes to reach every target (0 = immediate)"
  type        = number
  default     = 0
}

variable "growth_factor" {
  description = "Percentage of targets that receive the configuration per step"
  type        = number
  default     = 100
}

variable "growth_type" {
  description = "LINEAR or EXPONENTIAL"
  type        = string
  default     = "LINEAR"
}

variable "bake_time_minutes" {
  description = "Minutes to watch for alarms after a deployment before it counts as complete"
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags for every resource, on top of the provider's default tags"
  type        = map(string)
  default     = {}
}
