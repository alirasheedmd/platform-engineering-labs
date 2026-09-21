resource "digitalocean_vpc" "platform" {
  name        = "platform-k8s-vpc"
  region      = var.region
  ip_range    = var.vpc_ip_range
  description = "Private VPC for the Kubernetes platform lab"
}
