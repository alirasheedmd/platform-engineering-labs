variable "region" {
  description = "DigitalOcean region for platform infrastructure"
  type        = string
  default     = "blr1"
}

variable "vpc_ip_range" {
  description = "Private CIDR range for the platform VPC"
  type        = string
  default     = "10.10.10.0/24"
}
