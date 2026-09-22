resource "digitalocean_firewall" "platform" {
  name = "platform-k8s-firewall"

  tags = [
    "platform-lab",
  ]

  # Administrative SSH access from our trusted public IP only.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.ssh_allowed_cidr]
  }

  # Kubernetes API access from our trusted public IP.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6443"
    source_addresses = [var.ssh_allowed_cidr]
  }

  # Kubernetes nodes communicate with the API server over the private VPC.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "6443"
    source_addresses = [var.vpc_ip_range]
  }

  # Kubelet API communication inside the cluster.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "10250"
    source_addresses = [var.vpc_ip_range]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
