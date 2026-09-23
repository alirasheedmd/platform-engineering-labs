#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/infrastructure/terraform"
INVENTORY_FILE="$ROOT_DIR/configuration/ansible/inventory.ini"

CONTROL_PLANE_PUBLIC=$(
  terraform -chdir="$TERRAFORM_DIR" output -raw k8s_control_plane_public_ip
)

CONTROL_PLANE_PRIVATE=$(
  terraform -chdir="$TERRAFORM_DIR" output -raw k8s_control_plane_private_ip
)

WORKER_01_PUBLIC=$(
  terraform -chdir="$TERRAFORM_DIR" output -raw k8s_worker_01_public_ip
)

WORKER_01_PRIVATE=$(
  terraform -chdir="$TERRAFORM_DIR" output -raw k8s_worker_01_private_ip
)

cat > "$INVENTORY_FILE" <<EOF
[k8s_control_plane]
platform-k8s-cp-01 ansible_host=$CONTROL_PLANE_PUBLIC ansible_python_interpreter=/usr/bin/python3 k8s_private_ip=$CONTROL_PLANE_PRIVATE

[k8s_workers]
platform-k8s-worker-01 ansible_host=$WORKER_01_PUBLIC ansible_python_interpreter=/usr/bin/python3 k8s_private_ip=$WORKER_01_PRIVATE

[k8s_nodes:children]
k8s_control_plane
k8s_workers
EOF

echo "Generated $INVENTORY_FILE"
