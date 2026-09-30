#!/usr/bin/env bash
set -euo pipefail

: "${GHCR_USERNAME:?Set GHCR_USERNAME first}"
: "${GHCR_TOKEN:?Set GHCR_TOKEN first}"

kubectl create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username="${GHCR_USERNAME}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client \
  -o yaml |
kubectl apply -f -
