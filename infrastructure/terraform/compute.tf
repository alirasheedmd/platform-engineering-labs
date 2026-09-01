resource "digitalocean_droplet" "platform_node_01" {
  name   = "platform-node-01"
  region = var.region
  size   = var.droplet_size
  image  = var.droplet_image

  ssh_keys = [
    data.digitalocean_ssh_key.platform.id
  ]

  vpc_uuid = digitalocean_vpc.platform.id

  tags = [
    "platform-lab",
    "terraform-managed",
  ]
}
