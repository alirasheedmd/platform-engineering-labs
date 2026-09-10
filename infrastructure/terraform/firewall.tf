resource "digitalocean_firewall" "platform" {
  name = "platform-lab-firewall"

  tags = [
    "platform-lab",
  ]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.ssh_allowed_cidr]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

 # WireGuard VPN for GitHub Actions deployment access

 inbound_rule {
  protocol         = "udp"
  port_range       = "51820"
  source_addresses = ["0.0.0.0/0", "::/0"]
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
  # Swarm manager/control-plane communication
  inbound_rule {
    protocol         = "tcp"
    port_range       = "2377"
    source_addresses = ["10.10.10.0/24"]
  }

  # Swarm node discovery / gossip
  inbound_rule {
    protocol         = "tcp"
    port_range       = "7946"
    source_addresses = ["10.10.10.0/24"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "7946"
    source_addresses = ["10.10.10.0/24"]
  }

  # Overlay network VXLAN
  inbound_rule {
    protocol         = "udp"
    port_range       = "4789"
    source_addresses = ["10.10.10.0/24"]
  }
}
