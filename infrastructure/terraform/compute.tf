resource "digitalocean_droplet" "k8s_control_plane" {
  name   = "platform-k8s-cp-01"
  region = var.region
  size   = var.control_plane_size
  image  = var.droplet_image

  ssh_keys = [
    data.digitalocean_ssh_key.platform.id
  ]

  vpc_uuid = digitalocean_vpc.platform.id

  tags = [
    "platform-lab",
    "kubernetes",
    "control-plane",
    "terraform-managed",
  ]
}

resource "digitalocean_droplet" "k8s_worker_01" {
  name   = "platform-k8s-worker-01"
  region = var.region
  size   = var.worker_size
  image  = var.droplet_image

  ssh_keys = [
    data.digitalocean_ssh_key.platform.id
  ]

  vpc_uuid = digitalocean_vpc.platform.id

  tags = [
    "platform-lab",
    "kubernetes",
    "worker",
    "terraform-managed",
  ]
}
