resource "digitalocean_vpc" "platform" {
  name     = "platform-lab-vpc"
  region   = var.region
  ip_range = var.vpc_ip_range
}
