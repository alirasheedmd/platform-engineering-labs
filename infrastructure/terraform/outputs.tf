output "platform_node_01_public_ip" {
  description = "Public IPv4 address of platform node 01"
  value       = digitalocean_droplet.platform_node_01.ipv4_address
}

output "platform_node_01_private_ip" {
  description = "Private VPC IPv4 address of platform node 01"
  value       = digitalocean_droplet.platform_node_01.ipv4_address_private
}

output "platform_node_01_id" {
  description = "DigitalOcean ID of platform node 01"
  value       = digitalocean_droplet.platform_node_01.id
}
output "platform_node_02_public_ip" {
  description = "Public IPv4 address of platform node 02"
  value       = digitalocean_droplet.platform_node_02.ipv4_address
}

output "platform_node_02_private_ip" {
  description = "Private VPC IPv4 address of platform node 02"
  value       = digitalocean_droplet.platform_node_02.ipv4_address_private
}

output "platform_node_02_id" {
  description = "DigitalOcean ID of platform node 02"
  value       = digitalocean_droplet.platform_node_02.id
}
output "vpc_id" {
  description = "DigitalOcean VPC UUID"
  value       = data.digitalocean_vpc.platform.id
}
