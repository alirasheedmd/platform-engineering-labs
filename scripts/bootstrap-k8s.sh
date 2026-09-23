#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/infrastructure/terraform"
ANSIBLE_DIR="$ROOT_DIR/configuration/ansible"

echo "==> Generating Kubernetes Ansible inventory"

"$ROOT_DIR/scripts/generate-k8s-inventory.sh"

CONTROL_PLANE_PUBLIC=$(
  terraform -chdir="$TERRAFORM_DIR" output -raw k8s_control_plane_public_ip
)

WORKER_01_PUBLIC=$(
  terraform -chdir="$TERRAFORM_DIR" output -raw k8s_worker_01_public_ip
)

echo "==> Refreshing SSH host keys"

mkdir -p "$HOME/.ssh"
touch "$HOME/.ssh/known_hosts"

for host in "$CONTROL_PLANE_PUBLIC" "$WORKER_01_PUBLIC"; do
  ssh-keygen -R "$host" >/dev/null 2>&1 || true
  ssh-keyscan -T 5 -H "$host" >> "$HOME/.ssh/known_hosts" 2>/dev/null
done

cd "$ANSIBLE_DIR"

echo "==> Checking Kubernetes nodes individually"

for node in platform-k8s-cp-01 platform-k8s-worker-01; do

  echo "==> Checking $node"

  if ansible "$node" \
    -u platform \
    -m ping >/dev/null 2>&1; then

    echo "    $node already bootstrapped"

  elif ansible "$node" \
    -u root \
    -m ping >/dev/null 2>&1; then

    echo "    $node is fresh; bootstrapping as root"

    ansible-playbook \
      -u root \
      playbooks/k8s-bootstrap.yml \
      --limit "$node"

  else

    echo "ERROR: Cannot access $node as platform or root" >&2
    exit 1

  fi

done

echo "==> Verifying platform access on all Kubernetes nodes"

ansible k8s_nodes \
  -u platform \
  -m ping

echo "==> Kubernetes node bootstrap complete"
