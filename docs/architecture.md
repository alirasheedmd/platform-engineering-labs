# Platform Architecture

## Purpose

This document describes the current architecture of the Platform Engineering Lab.

It reflects the platform that has been implemented and validated through a clean-room rebuild, not merely the original target architecture.

The current system demonstrates:

- Terraform-managed cloud infrastructure,
- Ansible-managed host and platform configuration,
- a two-node Docker Swarm,
- private overlay networking,
- HTTPS ingress,
- WireGuard-based CI deployment connectivity,
- GitHub Actions CI/CD,
- GHCR-hosted immutable application artifacts,
- rebuild reproducibility,
- operational idempotency.

---

# Architecture Overview

```text
                              GitHub
                                 │
                                 │ push / workflow_dispatch
                                 ▼
                         GitHub Actions Runner
                                 │
                    ┌────────────┴─────────────┐
                    │                          │
                    │ build                    │ deployment
                    ▼                          ▼
                   GHCR                    WireGuard
                    │                          │
                    │                          │
                    │                     private VPN
                    │                          │
                    │                          ▼
                    │                  10.77.0.1
                    │                          │
                    └───────────────────┬──────┘
                                        │
                                        ▼
                              platform-node-01
                              Swarm Manager
                              VPC: 10.10.10.3
                                        │
                              platform-overlay
                                        │
                      ┌─────────────────┴─────────────────┐
                      │                                   │
                      ▼                                   ▼
              platform-node-01                    platform-node-02
              Swarm Manager                       Swarm Worker
              Ubuntu 24.04                        Ubuntu 24.04
              10.10.10.3                          10.10.10.2
                      │                                   │
                      └──────────────┬────────────────────┘
                                     │
                              lab-web service
                                4 replicas
                                     ▲
                                     │
                              lab-ingress
                                2 replicas
                              HTTP / HTTPS
                                     │
                                     ▼
                                  Internet
```

---

# Cloud Infrastructure

The platform currently runs on DigitalOcean.

The active compute layer contains two Ubuntu 24.04 Droplets:

```text
platform-node-01
    role: Swarm Manager
    VPC IP: 10.10.10.3

platform-node-02
    role: Swarm Worker
    VPC IP: 10.10.10.2
```

Both nodes are attached to the same private DigitalOcean VPC:

```text
10.10.10.0/24
```

The VPC is used for Swarm control-plane and overlay-network communication.

---

# Terraform Architecture

Terraform owns the disposable cloud infrastructure.

Current Terraform-managed resources include:

```text
digitalocean_droplet.platform_node_01
digitalocean_droplet.platform_node_02
digitalocean_firewall.platform
```

Terraform also reads external cloud dependencies using data sources:

```text
data.digitalocean_regions.available
data.digitalocean_ssh_key.platform
data.digitalocean_vpc.platform
```

This distinction is intentional.

```text
Terraform-managed
    → disposable infrastructure

Terraform data sources
    → external prerequisites
```

A full compute-layer rebuild destroys and recreates the Droplets and firewall, while the external VPC and cloud SSH-key identity remain available as prerequisites.

---

# Cloud Firewall

The cloud firewall separates public services from cluster-internal traffic.

Current inbound design:

```text
22/tcp
    → administrative source /32 only

80/tcp
    → public
    → HTTP ingress

443/tcp
    → public
    → HTTPS ingress

2377/tcp
    → 10.10.10.0/24 only
    → Swarm management

7946/tcp
7946/udp
    → 10.10.10.0/24 only
    → Swarm node discovery / gossip

4789/udp
    → 10.10.10.0/24 only
    → Swarm overlay VXLAN

51820/udp
    → public
    → WireGuard deployment tunnel
```

Swarm control-plane and overlay ports are not exposed publicly.

This keeps cluster coordination on the private VPC.

---

# Configuration Management Architecture

Terraform creates machines.

Ansible turns those machines into platform nodes.

The high-level configuration flow is:

```text
Terraform outputs
        ↓
generate-inventory.sh
        ↓
inventory.ini
        ↓
bootstrap-lab.sh
        ↓
Ansible
```

The generated inventory contains runtime addressing and is intentionally excluded from Git tracking.

---

# Ansible Responsibilities

Ansible owns the host and platform configuration layer.

Its responsibilities include:

```text
Linux baseline
    ↓
platform administrative user
    ↓
sudo configuration
    ↓
SSH hardening
    ↓
Docker Engine
    ↓
deployment SSH authorization
    ↓
WireGuard server
    ↓
Docker Swarm
    ↓
overlay networking
    ↓
bootstrap application state
    ↓
TLS
    ↓
HTTPS ingress
    ↓
platform verification
```

This boundary is important:

```text
Terraform
    does not configure the operating system

Ansible
    does not own application release identity
```

---

# Fresh Bootstrap Architecture

A newly created Droplet initially exposes only the administrative SSH access provisioned through DigitalOcean.

The bootstrap process detects whether the hosts are fresh.

Fresh-node path:

```text
administrative SSH identity
        ↓
root bootstrap
        ↓
platform user created
        ↓
SSH key installed
        ↓
passwordless sudo configured
        ↓
SSH hardened
        ↓
Docker installed
        ↓
root bootstrap no longer required
```

After this transition, platform operations use the `platform` administrative identity.

---

# Existing-Platform Path

On an already configured environment:

```text
bootstrap-lab.sh
        ↓
detect platform user
        ↓
skip root bootstrap
        ↓
reconcile platform configuration
```

The expected behavior is idempotent.

With unchanged desired state:

```text
changed=0
failed=0
unreachable=0
```

---

# Docker Swarm Architecture

The current cluster has two nodes:

```text
platform-node-01
    Manager
    Ready
    Active
    Leader

platform-node-02
    Worker
    Ready
    Active
```

The manager owns Swarm control-plane operations such as:

- service definitions,
- scheduling decisions,
- desired-state reconciliation,
- Docker Config and Secret management,
- worker join tokens.

The worker participates in application execution but does not participate as a manager.

---

# Swarm Networking

The platform uses an overlay network:

```text
platform-overlay
```

This network provides cross-node container connectivity.

Conceptually:

```text
platform-node-01                         platform-node-02
       │                                        │
       │           platform-overlay             │
       └────────────────┬───────────────────────┘
                        │
              service-to-service DNS
                        │
                        ▼
                    lab-web
```

Services communicate using Swarm service discovery rather than fixed container addresses.

---

# Application Architecture

The currently validated application service is:

```text
lab-web
```

Expected state:

```text
4 replicas
```

`lab-web` is not directly published to the Internet.

It is intentionally private inside the Swarm network.

```text
Internet
    ✕
lab-web directly

Internet
    ↓
lab-ingress
    ↓
platform-overlay
    ↓
lab-web
```

This separates public ingress from the application service.

---

# Ingress Architecture

The public ingress service is:

```text
lab-ingress
```

Expected state:

```text
2 replicas
```

It publishes:

```text
80/tcp
443/tcp
```

through Swarm.

The ingress behavior is:

```text
HTTP request
    ↓
301 redirect
    ↓
HTTPS

HTTPS request
    ↓
TLS termination
    ↓
Nginx
    ↓
lab-web:80
    ↓
platform-overlay
```

Both Swarm nodes can receive public traffic.

---

# TLS Architecture

The current environment uses self-signed TLS.

TLS lifecycle is managed by Ansible on the Swarm manager.

On fresh infrastructure:

```text
Ansible
    ↓
generate private key
    ↓
generate certificate request
    ↓
generate self-signed certificate
    ↓
validate certificate/key pair
```

The private key remains on the manager and is handled as private material.

---

# Docker Config and Secret Model

Ingress configuration is represented using immutable Docker objects.

```text
nginx.conf
    ↓
Docker Config

tls.crt
    ↓
Docker Config

tls.key
    ↓
Docker Secret
```

Public material can be represented as Docker Configs.

Private key material is represented as a Docker Secret.

Object identity is derived from content.

This allows a new certificate or configuration to create a new immutable object rather than mutating an existing one.

---

# Ingress Update Model

Ingress updates are validated before service reconciliation.

Conceptually:

```text
new Nginx configuration
        +
TLS material
        ↓
temporary validation container
        ↓
nginx -t
        ↓
certificate/key validation
        ↓
Docker Config / Secret creation
        ↓
rolling ingress update
```

The service update policy replaces replicas gradually.

A failed rollout can request rollback.

---

# CI/CD Architecture

Application delivery is owned by GitHub Actions.

The current release pipeline is:

```text
Developer
    ↓
git push
    ↓
GitHub
    ↓
lab-web-ci.yml
    ↓
validate application
    ↓
Docker Buildx
    ↓
build image
    ↓
push image
    ↓
GHCR
    ↓
capture OCI digest
    ↓
establish WireGuard tunnel
    ↓
SSH into Swarm manager
    ↓
authenticate manager to GHCR
    ↓
docker service update
    ↓
Swarm rolling deployment
    ↓
rollout verification
```

This separates application delivery from platform configuration.

---

# Artifact Identity

Application releases use both a Git SHA tag and OCI digest.

Example form:

```text
ghcr.io/alirasheedmd/platform-lab-web:
sha-<COMMIT>@sha256:<DIGEST>
```

The two identifiers serve different purposes:

```text
Git SHA
    → source traceability

OCI digest
    → immutable artifact identity
```

The digest ensures that the exact built image is deployed.

---

# CI Deployment Network

The GitHub Actions deployment path does not rely on public SSH directly.

The runner establishes a WireGuard tunnel to the manager.

```text
GitHub Actions
      │
      │ UDP 51820
      ▼
Public manager endpoint
      │
      ▼
WireGuard server
      │
      ▼
10.77.0.1
      │
      ▼
SSH deployment path
      │
      ▼
Swarm Manager
```

The deployment workflow then connects through the private WireGuard address.

This reduces exposure of the deployment control path.

---

# WireGuard Identity Model

The deployment VPN uses persistent cryptographic identities.

External persistent state includes:

```text
WG_PRIVATE_KEY
WG_SERVER_PUBLIC_KEY
```

The rebuilt manager restores its WireGuard server configuration from controlled secret state.

Therefore the server's WireGuard identity can remain stable even when the underlying VM is replaced.

---

# Deployment SSH Architecture

The CI runner uses a dedicated deployment SSH identity.

The private key is stored in GitHub:

```text
DEPLOY_SSH_PRIVATE_KEY
```

The matching public key is installed automatically on the Swarm manager by Ansible.

The deployment path becomes:

```text
GitHub Actions
    ↓
WireGuard
    ↓
deployment SSH key
    ↓
platform@10.77.0.1
    ↓
sudo docker ...
```

This identity is distinct from the administrative SSH identity used to bootstrap fresh infrastructure.

---

# Administrative vs Deployment Identity

The architecture intentionally separates two SSH use cases.

## Administrative Identity

Used for:

- fresh-node bootstrap,
- emergency administrative access,
- full Ansible configuration across manager and worker.

Provisioned through the DigitalOcean SSH-key mechanism.

---

## Deployment Identity

Used for:

- GitHub Actions,
- application deployment,
- manager-side Docker/Swarm operations.

Installed only after bootstrap.

This avoids depending on a deployment credential before its server-side authorization exists.

---

# GitHub External State

Some CI/CD state lives outside the platform itself.

The current workflows depend on:

```text
DEPLOY_SSH_PRIVATE_KEY
GHCR_READ_TOKEN
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
WG_PRIVATE_KEY
WG_SERVER_PUBLIC_KEY
```

GitHub also automatically provides:

```text
GITHUB_TOKEN
```

---

# Dynamic GitHub State

Two GitHub values are coupled to the identity of the current manager:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

These values become stale after manager replacement.

Therefore:

```text
Terraform rebuild
      ↓
new manager
      ↓
new public IP
new SSH host key
      ↓
sync-github-secrets.sh
      ↓
GitHub deployment state reconciled
```

This external reconciliation step is part of the platform architecture, not an optional convenience.

---

# Secret Synchronization Boundary

The script:

```text
scripts/sync-github-secrets.sh
```

bridges two separate control planes:

```text
Terraform / cloud state
        ↓
local reconciliation script
        ↓
GitHub repository state
```

This is a critical architectural boundary.

Terraform itself does not currently own GitHub repository secrets.

The rebuild process must therefore explicitly reconcile them.

---

# CI Connectivity Validation

Before running the application release pipeline, a dedicated workflow validates only the deployment path:

```text
platform-connectivity.yml
```

It checks:

```text
GitHub runner
    ↓
WireGuard installation
    ↓
WireGuard configuration
    ↓
VPN reachability
    ↓
SSH key setup
    ↓
SSH over WireGuard
    ↓
Docker access
    ↓
Swarm manager access
    ↓
GHCR authentication
```

This isolates connectivity failures from application build failures.

---

# Platform Control Planes

The platform contains several distinct control planes.

## Cloud Control Plane

```text
Terraform
    ↓
DigitalOcean API
```

Controls:

- compute,
- firewall,
- cloud associations.

---

## Configuration Control Plane

```text
Ansible
    ↓
SSH
    ↓
platform nodes
```

Controls:

- OS configuration,
- Docker,
- security baseline,
- WireGuard,
- Swarm bootstrap,
- ingress.

---

## Swarm Control Plane

```text
platform-node-01
    ↓
Docker Swarm Manager
```

Controls:

- cluster membership,
- desired service state,
- scheduling,
- rolling updates,
- Docker Configs,
- Docker Secrets.

---

## Application Delivery Control Plane

```text
GitHub Actions
    ↓
WireGuard
    ↓
SSH
    ↓
Swarm manager
```

Controls:

- application build,
- artifact publication,
- release deployment.

---

# Data Plane

The runtime data path is separate from these control planes.

Public application traffic flows:

```text
Internet
    ↓
DigitalOcean firewall
    ↓
Swarm published port
    ↓
lab-ingress
    ↓
platform-overlay
    ↓
lab-web
```

The application service is therefore shielded behind ingress.

---

# Trust Boundaries

The platform contains several important trust boundaries.

```text
Internet
    │
    │ HTTP / HTTPS
    ▼
Public ingress boundary
    │
    ▼
Swarm overlay boundary
    │
    ▼
Private application

GitHub-hosted runner
    │
    │ WireGuard
    ▼
Deployment VPN boundary
    │
    │ SSH
    ▼
Platform administration boundary

Local operator
    │
    │ administrative SSH
    ▼
Fresh-node bootstrap boundary
```

Each boundary uses a different access mechanism.

---

# Security Boundaries

## Public Traffic

Publicly exposed:

```text
80/tcp
443/tcp
51820/udp
```

Administrative SSH is restricted to the configured administrative source.

Swarm cluster ports are private to the VPC.

---

## Secrets

Secret material is intentionally kept outside normal source control.

Examples include:

- cloud API credentials,
- SSH private keys,
- WireGuard private keys,
- GHCR credentials,
- Ansible Vault protected values,
- TLS private key material.

---

## Docker Socket / Docker Access

Docker administrative access is effectively privileged host access.

The platform therefore treats Docker permissions as part of the administrative trust boundary.

The CI workflow explicitly verifies Docker access before attempting deployment.

---

# Ownership Boundaries

One of the most important architecture rules is that each layer owns a different class of state.

```text
Terraform
    owns infrastructure identity

Ansible
    owns host/platform configuration

Docker Swarm
    owns runtime desired state

GitHub Actions
    owns application release identity

GHCR
    owns application artifact storage
```

This prevents configuration tools from fighting over the same state.

---

# Application Release Preservation

A fresh platform needs a bootstrap application state.

Therefore Ansible can create the initial `lab-web` service.

Once GitHub Actions deploys a real application release:

```text
Ansible bootstrap image
        ↓
CI deployment
        ↓
GHCR SHA + digest
```

Ansible must preserve the CI-managed image during subsequent runs.

This behavior was explicitly validated:

```text
bootstrap rerun
    ↓
changed=0
    ↓
existing GHCR release retained
```

---

# Rebuild Architecture

The full reconstruction path is:

```text
Repository
    ↓
Terraform
    ↓
DigitalOcean infrastructure
    ↓
Terraform outputs
    ↓
generated Ansible inventory
    ↓
bootstrap-lab.sh
    ↓
Linux + Docker + security baseline
    ↓
WireGuard
    ↓
Swarm
    ↓
overlay
    ↓
TLS + ingress
    ↓
platform verification
    ↓
sync-github-secrets.sh
    ↓
GitHub external-state reconciliation
    ↓
platform-connectivity.yml
    ↓
private deployment-path verification
    ↓
lab-web-ci.yml
    ↓
immutable application release
    ↓
public validation
```

---

# Dependency Closure

A rebuild is not considered complete merely because infrastructure exists.

When a component is recreated, the rebuild procedure evaluates:

```text
What identity changed?

What references that identity?

What state survived destruction?

What became stale?

What downstream control plane depends on it?

What evidence proves that dependency still works?
```

Example:

```text
Manager VM replaced
    ↓
public IP changes
SSH host key changes
    ↓
GitHub repository state becomes stale
    ↓
synchronize secrets
    ↓
run connectivity validation
    ↓
only then deploy application
```

This dependency-closure model is part of the architecture because the platform spans multiple state domains.

---

# State Domains

The platform can be viewed as several separate state domains.

## Source-Controlled State

```text
Terraform code
Ansible code
shell automation
GitHub workflow definitions
application source
documentation
```

---

## Terraform State

Represents the mapping between infrastructure configuration and provisioned cloud resources.

---

## Cloud-External State

Includes:

```text
DigitalOcean VPC
DigitalOcean SSH key
API credentials
```

These survive compute destruction.

---

## Secret State

Includes:

```text
Ansible Vault
GitHub repository secrets
SSH private keys
WireGuard private keys
registry credentials
```

---

## Swarm Runtime State

Includes:

```text
node membership
services
tasks
overlay networks
Docker Configs
Docker Secrets
current release
```

---

## Generated Local State

Includes:

```text
configuration/ansible/inventory.ini
```

The inventory is derived from Terraform outputs and is intentionally not source-controlled.

---

# Failure Domains

The current architecture has several distinct failure domains.

## Single Manager

There is one Swarm manager.

Loss of the manager affects control-plane availability.

The worker may continue running existing tasks, but cluster management cannot be considered highly available.

This lab therefore demonstrates multi-node workload scheduling, not manager quorum HA.

---

## Two Ingress Replicas

Ingress runs with two replicas.

This allows traffic to be accepted through either node when both are healthy.

However, cloud-level traffic distribution currently relies on direct node reachability rather than an external managed load balancer.

---

## Stateless Application

The currently validated `lab-web` workload is stateless.

This makes clean reconstruction straightforward.

Stateful workloads require a separate recovery model.

---

## External Secret Dependencies

If GitHub, Vault, SSH or WireGuard secret state is lost, infrastructure alone is not sufficient to recover the deployment path.

These values are therefore part of the platform recovery model.

---

# Stateful Workload Boundary

Earlier lab exercises included Redis and node-local storage behavior.

Those exercises demonstrated:

- persistence semantics,
- scheduling behavior,
- node-local volume limitations,
- failure/restart behavior.

They do not constitute a production stateful recovery architecture.

The current validated clean-room architecture should therefore be described as:

```text
reproducible stateless application platform
```

rather than a fully disaster-recoverable stateful platform.

---

# Observability Boundary

The repository architecture originally included planned observability components such as:

```text
Prometheus
Grafana
Node Exporter
cAdvisor
```

These are not currently part of the validated clean-room rebuild path.

They remain a future platform maturity phase.

Health verification currently relies primarily on:

- Docker/Swarm service state,
- application health behavior,
- ingress validation,
- Ansible verification,
- CI rollout verification,
- direct HTTP testing.

---

# Current Validated Architecture

As of the September 18, 2026 clean-room validation, the platform has proven:

```text
Infrastructure as Code           ✅
Two-node cloud infrastructure     ✅
Private VPC networking            ✅
Cloud firewall segregation        ✅
Configuration management          ✅
SSH hardening                     ✅
Docker automation                 ✅
Multi-node Docker Swarm           ✅
Overlay networking                ✅
WireGuard deployment plane        ✅
Private CI SSH deployment         ✅
HTTPS ingress                     ✅
TLS lifecycle automation          ✅
Docker Config / Secret lifecycle  ✅
GHCR registry                     ✅
Immutable application artifacts   ✅
GitHub Actions CI/CD              ✅
Rolling application deployment    ✅
Clean-room reconstruction         ✅
External state reconciliation     ✅
Operational idempotency           ✅
Release ownership preservation    ✅
```

---

# Current Limitations

The architecture does not currently claim:

- highly available Swarm manager quorum,
- managed external load balancing,
- publicly trusted TLS certificates,
- production-grade secrets management,
- production-grade stateful workload recovery,
- automated backup and restore,
- full observability stack,
- multi-region operation,
- Kubernetes orchestration.

These are explicit boundaries, not hidden assumptions.

---

# Architectural Principles Demonstrated

This lab currently demonstrates the following platform engineering principles.

## Separate State Ownership

Do not allow multiple automation systems to fight over the same state.

---

## Prefer Declarative Reconciliation

The desired outcome should be encoded in Terraform, Ansible, Swarm and CI rather than remembered as manual shell steps.

---

## Treat Generated Data as Generated Data

Ephemeral infrastructure values such as generated inventory addresses should not become source-controlled state.

---

## Keep Cluster Traffic Private

Swarm control-plane and overlay communication belong on private networking.

---

## Minimize Public Exposure

Expose ingress and required VPN connectivity, not cluster internals.

---

## Separate Administrative and Deployment Identity

Fresh-node administration and routine application deployment have different trust requirements.

---

## Use Immutable Release Identity

A Git tag alone is not sufficient artifact identity.

The release is pinned using the image digest.

---

## Validate Across Layers

A successful CI workflow is not enough.

Validate:

```text
control-plane state
+
runtime state
+
artifact identity
+
user-visible behavior
```

---

## Reconcile External State After Replacement

Not every dependency is stored in Terraform.

Infrastructure recreation must account for external systems that reference the old resource identity.

---

## Idempotency Is an Operational Requirement

Automation must be safe to run against both:

```text
fresh infrastructure

and

already-running infrastructure
```

without unnecessary mutation.

---

# Related Documentation

Operational rebuild procedure:

```text
docs/runbooks/rebuild.md
```

Reproducibility model and validation:

```text
docs/reproducibility.md
```

Historical ingress validation:

```text
docs/validation/2026-09-17-ingress.md
```

The September 18 clean-room rebuild should also be retained as a dedicated validation record.

---

# Architecture Summary

The platform currently follows this operating model:

```text
Terraform
    builds infrastructure

Ansible
    builds the platform

Docker Swarm
    maintains runtime state

GitHub Actions
    delivers releases

GHCR
    stores immutable artifacts

WireGuard
    protects the deployment path

Ingress
    exposes the application

Validation
    proves the layers agree
```

The objective is not to maximize the number of tools in the stack.

The objective is to create clear ownership, reproducible infrastructure, controlled trust boundaries, predictable reconciliation and evidence that the platform continues to operate after destruction and reconstruction.
