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
variable "droplet_size" {
  description = "DigitalOcean Droplet size used by the initial platform node"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "droplet_image" {
  description = "Operating system image for platform nodes"
  type        = string
  default     = "ubuntu-24-04-x64"
}
variable "ssh_allowed_cidr" {
  description = "Public IPv4 CIDR permitted to SSH into platform nodes"
  type        = string
}
