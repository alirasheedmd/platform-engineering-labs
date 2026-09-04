#!/usr/bin/env bash

set -euo pipefail

TERRAFORM_DIR="infrastructure/terraform"
INVENTORY_FILE="configuration/ansible/inventory.ini"

NODE1_PUBLIC=$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_node_01_public_ip)
NODE1_PRIVATE=$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_node_01_private_ip)

NODE2_PUBLIC=$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_node_02_public_ip)
NODE2_PRIVATE=$(terraform -chdir="$TERRAFORM_DIR" output -raw platform_node_02_private_ip)

cat > "$INVENTORY_FILE" <<EOF
[swarm_managers]
platform-node-01 ansible_host=$NODE1_PUBLIC ansible_python_interpreter=/usr/bin/python3 swarm_advertise_addr=$NODE1_PRIVATE

[swarm_workers]
platform-node-02 ansible_host=$NODE2_PUBLIC ansible_python_interpreter=/usr/bin/python3 swarm_advertise_addr=$NODE2_PRIVATE

[platform_nodes:children]
swarm_managers
swarm_workers
EOF

echo "Generated $INVENTORY_FILE"
