#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/infrastructure/terraform"
ANSIBLE_DIR="$ROOT_DIR/configuration/ansible"

echo "==> Generating Ansible inventory"
"$ROOT_DIR/scripts/generate-inventory.sh"

echo "==> Refreshing SSH host keys"

NODE1_PUBLIC=$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_node_01_public_ip)
NODE2_PUBLIC=$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_node_02_public_ip)

for host in "$NODE1_PUBLIC" "$NODE2_PUBLIC"; do
  ssh-keygen -R "$host" >/dev/null 2>&1 || true
  ssh-keyscan -H "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null
done

cd "$ANSIBLE_DIR"

echo "==> Checking whether nodes are already bootstrapped"

if ansible platform_nodes \
  -u platform \
  -m ping >/dev/null 2>&1; then

  echo "==> Platform user is available; skipping root bootstrap"

else

  echo "==> Fresh nodes detected; bootstrapping as root"

  ansible-playbook \
    -u root \
    playbooks/bootstrap.yml
fi

echo "==> Configuring Swarm and services as platform user"

ansible-playbook \
  -u platform \
  playbooks/site.yml

echo "==> Verifying Swarm cluster"

ansible swarm_managers \
  -u platform \
  -b \
  -m command \
  -a "docker node ls"

echo "==> Verifying Swarm services"

ansible swarm_managers \
  -u platform \
  -b \
  -m command \
  -a "docker service ls"

echo "==> Lab bootstrap complete"
