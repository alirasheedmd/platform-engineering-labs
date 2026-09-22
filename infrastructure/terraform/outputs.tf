output "k8s_control_plane_public_ip" {
  description = "Public IPv4 address of the Kubernetes control-plane node"
  value       = digitalocean_droplet.k8s_control_plane.ipv4_address
}

output "k8s_control_plane_private_ip" {
  description = "Private VPC IPv4 address of the Kubernetes control-plane node"
  value       = digitalocean_droplet.k8s_control_plane.ipv4_address_private
}

output "k8s_control_plane_id" {
  description = "DigitalOcean ID of the Kubernetes control-plane node"
  value       = digitalocean_droplet.k8s_control_plane.id
}

output "k8s_worker_01_public_ip" {
  description = "Public IPv4 address of Kubernetes worker 01"
  value       = digitalocean_droplet.k8s_worker_01.ipv4_address
}

output "k8s_worker_01_private_ip" {
  description = "Private VPC IPv4 address of Kubernetes worker 01"
  value       = digitalocean_droplet.k8s_worker_01.ipv4_address_private
}

output "k8s_worker_01_id" {
  description = "DigitalOcean ID of Kubernetes worker 01"
  value       = digitalocean_droplet.k8s_worker_01.id
}

output "vpc_id" {
  description = "DigitalOcean VPC UUID"
  value       = digitalocean_vpc.platform.id
}

