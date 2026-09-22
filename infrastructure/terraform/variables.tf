variable "region" {
  description = "DigitalOcean region for platform infrastructure"
  type        = string
  default     = "blr1"
}

variable "vpc_ip_range" {
  description = "Private CIDR range for the Kubernetes platform VPC"
  type        = string
  default     = "10.20.0.0/24"
}
variable "control_plane_size" {
  description = "DigitalOcean Droplet size for the Kubernetes control-plane node"
  type        = string
  default     = "s-2vcpu-2gb"
}

variable "worker_size" {
  description = "DigitalOcean Droplet size for Kubernetes worker nodes"
  type        = string
  default     = "s-2vcpu-2gb"
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
