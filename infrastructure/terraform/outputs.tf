output "platform_node_public_ip" {
  description = "Public IPv4 address of the initial platform node"
  value       = digitalocean_droplet.platform_node_01.ipv4_address
}

output "platform_node_private_ip" {
  description = "Private VPC IPv4 address of the initial platform node"
  value       = digitalocean_droplet.platform_node_01.ipv4_address_private
}

output "platform_node_id" {
  description = "DigitalOcean ID of the initial platform node"
  value       = digitalocean_droplet.platform_node_01.id
}

output "vpc_id" {
  description = "DigitalOcean VPC UUID"
  value       = digitalocean_vpc.platform.id
}
