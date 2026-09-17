#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="$ROOT_DIR/infrastructure/terraform"

REPO="alirasheedmd/platform-engineering-labs"
ADMIN_SSH_KEY="${ADMIN_SSH_KEY:-$HOME/.ssh/id_ed25519}"
VPN_MANAGER_IP="10.77.0.1"

echo "==> Reading manager public IP from Terraform"

MANAGER_IP="$(
  terraform -chdir="$TERRAFORM_DIR" \
    output -raw platform_node_01_public_ip
)"

echo "Manager public IP: $MANAGER_IP"

echo "==> Reading manager SSH ED25519 host key"


echo "==> Waiting for manager SSH"

for attempt in {1..30}; do
  if ssh \
      -o BatchMode=yes \
      -o ConnectTimeout=5 \
      -i "$ADMIN_SSH_KEY" \
      "platform@$MANAGER_IP" \
      'true' 2>/dev/null; then
    echo "Manager SSH is ready"
    break
  fi

  if [[ "$attempt" -eq 30 ]]; then
    echo "ERROR: Manager SSH did not become ready"
    exit 1
  fi

  sleep 5
done


HOST_KEY="$(
  ssh \
    -o BatchMode=yes \
    -i "$ADMIN_SSH_KEY" \
    "platform@$MANAGER_IP" \
    'sudo -n cat /etc/ssh/ssh_host_ed25519_key.pub'
)"

read -r KEY_TYPE KEY_DATA _ <<< "$HOST_KEY"

if [[ -z "${KEY_TYPE:-}" || -z "${KEY_DATA:-}" ]]; then
  echo "ERROR: Could not parse SSH host key"
  exit 1
fi

KNOWN_HOST="$VPN_MANAGER_IP $KEY_TYPE $KEY_DATA"

echo "==> SSH host key fingerprint"

printf '%s\n' "$HOST_KEY" | ssh-keygen -lf -

echo "==> Updating GitHub repository secrets"

printf '%s' "$MANAGER_IP" \
  | gh secret set PLATFORM_MANAGER_PUBLIC_IP \
      --repo "$REPO"

printf '%s' "$KNOWN_HOST" \
  | gh secret set PLATFORM_SSH_KNOWN_HOST \
      --repo "$REPO"

echo "==> GitHub secrets synchronized successfully"
