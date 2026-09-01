# Platform Engineering Lab

A production-oriented platform engineering lab built from first principles using **Terraform, Ansible, Docker, Docker Swarm, CI/CD, observability, and failure testing**.

The goal of this project is not just to deploy containers. It is to understand how a small production platform is designed, automated, operated, broken, recovered, and improved over time.

---

## Why This Lab Exists

A common small-company infrastructure setup starts simply:

- One Ubuntu server
- Several Docker Compose applications
- Manual deployments
- Application-specific networks
- SSH-based operations
- Little visibility into workload health
- Unclear scaling and failure-recovery strategy

That setup works initially, but operational complexity increases as more services are added.

This lab starts from that type of environment and progressively evolves it into a reproducible and observable platform.

The learning process follows this pattern:

```text
Understand the fundamental
        ↓
Build the simplest solution
        ↓
Experience a real limitation
        ↓
Introduce the appropriate tool
        ↓
Break the system intentionally
        ↓
Recover it
        ↓
Automate it
        ↓
Document the operational model
```

---

# Target Architecture

```text
                         GitHub
                            │
                            │ push
                            ▼
                     GitHub Actions
                            │
                      test / build
                            │
                            ▼
                   Container Registry
                            │
                            ▼
                    Docker Swarm
                            │
               ┌────────────┴────────────┐
               │                         │
         Manager Node               Worker Node
               │                         │
               └──── Overlay Network ────┘
                            │
                ┌───────────┼───────────┐
                │           │           │
             Frontend     Backend      Redis
             replicas     replicas
                │
                ▼
          Reverse Proxy / Ingress
                │
                ▼
             Internet

       Monitoring, health checks and logs
             around the platform
```

Infrastructure responsibilities are intentionally separated:

```text
Terraform
    ↓
Cloud infrastructure

Ansible
    ↓
Operating system and host configuration

Docker / Swarm
    ↓
Application runtime and orchestration

CI/CD
    ↓
Application delivery

Observability
    ↓
Platform and application visibility
```

---

# Technology Stack

## Infrastructure as Code

- Terraform
- DigitalOcean Provider
- DigitalOcean VPC
- Droplets
- Cloud Firewalls
- SSH key references

## Configuration Management

- Ansible
- Role-based configuration
- SSH hardening
- Administrative user provisioning
- Docker installation and configuration

## Containers

- Docker Engine
- Docker Compose
- User-defined bridge networks
- Docker Swarm

## Planned Platform Components

- Multi-node Docker Swarm
- Overlay networking
- Container registry
- GitHub Actions
- Reverse proxy / ingress
- Health checks
- Rolling deployments
- Prometheus
- Grafana
- Node Exporter
- cAdvisor

---

# Repository Structure

```text
platform-lab/
│
├── .github/
│   └── workflows/
│
├── apps/
│   ├── backend/
│   └── frontend/
│
├── configuration/
│   └── ansible/
│       ├── ansible.cfg
│       ├── inventory.ini
│       ├── playbooks/
│       └── roles/
│
├── infrastructure/
│   └── terraform/
│
├── platform/
│   └── swarm/
│
├── observability/
│
├── docs/
│
├── scripts/
│
└── README.md
```

---

# Current Infrastructure

The initial environment consists of a DigitalOcean Ubuntu node provisioned entirely through Terraform.

```text
DigitalOcean
│
├── VPC
│   └── 10.10.10.0/24
│
├── platform-node-01
│   ├── Ubuntu 24.04
│   ├── Public interface
│   └── Private VPC interface
│
└── Cloud Firewall
```

The private VPC is intentionally used for internal cluster communication.

Public IP addresses, API tokens, Terraform variable files and credentials are not committed to the repository.

---

# Terraform

Terraform currently manages:

- DigitalOcean provider configuration
- VPC
- Droplet
- SSH key lookup
- Droplet tags
- DigitalOcean firewall
- Infrastructure outputs

Key concepts explored:

- Providers
- Resources
- Data sources
- Variables
- Outputs
- Dependency graphs
- Terraform state
- Provider authentication
- Least-privilege API access
- Planning versus applying infrastructure changes

One useful failure encountered during the lab was an API authorization error caused by a missing `tag:create` scope.

Instead of giving the API token unrestricted access, the required permission was identified and added.

This reinforced an important principle:

> Infrastructure automation credentials should receive the permissions required by the infrastructure definition, not blanket administrative access.

---

# Ansible

Terraform creates the machines.

Ansible turns those machines into platform-ready hosts.

The current Ansible structure uses roles such as:

```text
roles/
├── common/
├── ssh_hardening/
├── docker/
└── swarm/
```

The baseline configuration currently includes:

- Platform administrative user
- SSH public-key authentication
- Passwordless sudo with controlled sudoers configuration
- Root SSH disabled
- Password authentication disabled
- Keyboard-interactive authentication disabled
- Baseline Linux utilities
- Docker official APT repository
- Docker Engine
- Docker CLI
- containerd
- Docker Buildx
- Docker Compose plugin

The playbooks are designed to be idempotent.

Running the same configuration repeatedly should converge toward:

```text
changed=0
failed=0
```

once the desired configuration is already present.

---

# SSH Security Model

The initial cloud image allowed root-based bootstrap access.

Ansible then created the dedicated:

```text
platform
```

administrative account.

The hardened access model became:

```text
Engineer
    │
    │ SSH key
    ▼
platform user
    │
    │ sudo
    ▼
privileged operation
```

Direct root SSH is disabled.

Password-based SSH authentication is also disabled.

SSH configuration is managed through:

```text
/etc/ssh/sshd_config.d/
```

and configuration changes are validated with `sshd -t` before the SSH service is reloaded.

---

# Docker Runtime Lessons

The lab intentionally explores Docker below the Compose abstraction.

Topics covered include:

- Image versus container
- Docker daemon
- containerd
- Docker socket
- Published ports
- Container lifecycle
- Container filesystem state
- Docker networking
- Runtime debugging

One important security lesson involved:

```text
/var/run/docker.sock
```

Users able to control the Docker daemon effectively have root-equivalent control over the host.

For that reason, the platform user has not simply been added to the `docker` group.

Current access is intentionally:

```text
platform
    ↓
sudo
    ↓
Docker
```

---

# Docker Networking

## Default Bridge

An initial experiment demonstrated that container-name resolution does not behave the way many users expect on Docker's legacy default bridge network.

```text
Container A
    │
    │ lab-nginx
    ▼
Default bridge

DNS resolution failed
```

---

## User-Defined Bridge

A user-defined bridge network was then introduced:

```text
Container A
       │
       │ Docker DNS
       ▼
     lab-net
       │
       ▼
   lab-nginx
```

Container-name resolution worked correctly.

This demonstrated that Docker networking is more than IP connectivity—it also provides service discovery when using appropriate user-defined networks.

---

# Reproducing a Real Compose Problem

The lab then reproduced a common production situation:

```text
backend Compose project

redis Compose project
```

Each Compose project automatically created its own network:

```text
backend_default

redis_default
```

The result:

```text
Backend
   │
   │ lab-redis
   ▼
Redis

FAILED
```

The containers were healthy, but they were attached to different isolated networks.

---

# Shared External Network

The initial solution did not require an orchestrator.

A shared external Docker bridge network allowed independent Compose stacks to communicate:

```text
Backend
    │
    │
shared-net
    │
    │
Redis
```

Redis connectivity was verified successfully:

```text
PONG
```

This produced an important architectural conclusion:

> Cross-Compose communication on a single host does not, by itself, justify introducing Docker Swarm.

Use the simplest tool that actually solves the current problem.

---

# Container Immutability Lesson

During testing, `redis-cli` was manually installed inside the backend container.

Later, Docker Compose recreated that container.

The manually installed package disappeared.

```text
Image
  ↓
Container created
  ↓
Manual package installation
  ↓
Container recreated
  ↓
Manual change disappeared
```

This demonstrated the difference between:

```text
Dockerfile / image state
    =
reproducible software definition
```

and:

```text
manual docker exec changes
    =
temporary container drift
```

Application dependencies should belong in the image definition rather than being manually installed into running production containers.

---

# Docker Swarm

Docker Swarm was introduced only after understanding what single-host Compose could already solve.

The current node has been initialized as a Swarm manager through Ansible.

```text
platform-node-01
│
├── Ready
├── Active
└── Leader
```

The Swarm manager advertises itself over the private platform VPC rather than the public interface.

---

# Service, Task and Container

Swarm introduces an important hierarchy:

```text
Service
   │
   ├── Task 1
   │     └── Container
   │
   ├── Task 2
   │     └── Container
   │
   └── Task 3
         └── Container
```

Instead of requesting:

```text
Create this particular container.
```

a Swarm service describes desired state:

```text
Maintain three replicas of this application.
```

---

# Desired-State Reconciliation

A replicated Nginx service was created:

```text
lab-web
replicas = 3
```

One underlying container was intentionally removed.

Swarm observed:

```text
Desired = 3
Actual  = 2
```

and created a replacement task automatically.

The platform returned to:

```text
3/3 replicas
```

without manually recreating the deleted container.

This demonstrated one of the core ideas behind modern orchestration systems:

> Operators declare desired state. Controllers continuously reconcile actual state toward it.

---

# Replicas Do Not Automatically Mean More Capacity

The current lab deliberately runs several replicas on a single small node.

```text
platform-node-01

├── lab-web.1
├── lab-web.2
└── lab-web.3
```

All replicas share the same:

- CPU
- Memory
- Disk
- Network interface
- Host failure domain

Therefore:

```text
3 replicas on one 1-vCPU VM
```

does not mean:

```text
3 × compute capacity
```

Replicas on a single host can provide process-level redundancy and help with rolling updates, but true horizontal capacity and node-level availability require additional compute nodes.

This distinction becomes important when the lab moves to multi-node orchestration.

---

# Performance and Capacity

A container does not have a universal request-per-second limit.

Capacity depends on:

- Application implementation
- CPU
- Memory
- Database latency
- Network latency
- Request complexity
- Payload size
- External dependencies
- Runtime behavior

Capacity should therefore be measured through load testing.

A production capacity statement should look more like:

```text
One application replica sustains 250 requests/sec
while:

p95 latency < 250 ms
error rate < 1%
CPU < 70%
memory remains stable
```

rather than:

```text
One Docker container can handle X users.
```

Replica planning can then be based on measured capacity:

```text
Required replicas
≈
Peak expected requests/sec
÷
Safe measured requests/sec per replica
```

plus additional failure and deployment headroom.

---

# Failure Domains

An important reliability concept explored in this project is the difference between replica count and failure isolation.

```text
Three replicas
on one VM
```

protect against some application-process failures.

They do not protect against:

```text
VM failure
host kernel failure
host network failure
disk failure
datacenter failure
```

A production platform therefore needs to reason about failure domains:

```text
Application process
        ↓
Container
        ↓
Node
        ↓
Network
        ↓
Availability zone / datacenter
```

The question to repeatedly ask is:

> If this component disappears right now, what exactly stops working?

---

# Current Progress

```text
Terraform / IaC              █████████░  ~90%
Ansible                      ████████░░  ~85%
Linux security baseline      ████████░░  ~80%
Docker fundamentals          ███████░░░  ~70%
Docker Compose               ███████░░░  ~70%
Docker Swarm                 ███░░░░░░░  ~30%
Multi-node orchestration     ░░░░░░░░░░
Container registry           ░░░░░░░░░░
CI/CD                        ░░░░░░░░░░
Observability                ░░░░░░░░░░
```

---

# Roadmap

## Phase 1 — Foundation

- [x] Repository architecture
- [x] Terraform provider
- [x] DigitalOcean VPC
- [x] Terraform-managed Droplet
- [x] Cloud firewall
- [x] Infrastructure outputs
- [x] Ansible baseline
- [x] Dedicated platform user
- [x] SSH hardening
- [x] Docker installation through Ansible

---

## Phase 2 — Container Fundamentals

- [x] Docker runtime
- [x] Images and containers
- [x] Published ports
- [x] Docker socket security
- [x] Default bridge networking
- [x] User-defined bridge networking
- [x] Docker DNS
- [x] Separate Compose network failure
- [x] Shared external Compose network
- [x] Container immutability experiment

---

## Phase 3 — Swarm Fundamentals

- [x] Initialize manager through Ansible
- [x] Understand nodes
- [x] Understand managers and workers
- [x] Create replicated service
- [x] Understand services, tasks and containers
- [x] Desired-state reconciliation
- [ ] Scale replicas
- [ ] Overlay networking
- [ ] Service discovery
- [ ] Internal load balancing
- [ ] Rolling updates
- [ ] Rollback

---

## Phase 4 — Multi-Node Platform

- [ ] Provision second node with Terraform
- [ ] Configure it through Ansible
- [ ] Join it to Swarm
- [ ] Schedule workloads across nodes
- [ ] Placement constraints
- [ ] Drain and activate nodes
- [ ] Test worker failure
- [ ] Understand manager quorum

---

## Phase 5 — Production Workload Delivery

- [ ] Container registry
- [ ] Versioned images
- [ ] GitHub Actions
- [ ] Automated builds
- [ ] Automated deployment
- [ ] Deployment verification
- [ ] Rollback workflow

---

## Phase 6 — Production Operations

- [ ] Reverse proxy / ingress
- [ ] TLS
- [ ] Health checks
- [ ] Resource reservations and limits
- [ ] Secrets
- [ ] Stateful workload strategy
- [ ] Persistent storage
- [ ] Backups

---

## Phase 7 — Observability

- [ ] Prometheus
- [ ] Grafana
- [ ] Node Exporter
- [ ] cAdvisor
- [ ] Platform health visibility
- [ ] Service-level metrics

---

## Phase 8 — Failure Engineering

Planned experiments include:

- [x] Delete a service container
- [ ] Crash application process
- [ ] Stop Docker daemon
- [ ] Drain worker
- [ ] Lose worker node
- [ ] Deploy bad application version
- [ ] Break health check
- [ ] Break service networking
- [ ] Test resource exhaustion
- [ ] Test rollback

Each failure experiment should answer:

```text
What failed?

How was it detected?

What recovered automatically?

What required human intervention?

How would this be prevented or mitigated in production?
```

---

# Final Validation

The final test for this project will be intentionally destructive.

Destroy the infrastructure:

```bash
terraform destroy
```

Then rebuild the platform using only:

```text
Git repository
Terraform
Ansible
Cloud credentials
SSH credentials
```

Expected flow:

```text
terraform apply
        ↓
infrastructure created
        ↓
Ansible configuration
        ↓
platform nodes ready
        ↓
Swarm cluster created
        ↓
applications deployed
        ↓
monitoring online
```

If the platform cannot be rebuilt without undocumented manual steps, the automation or documentation is incomplete.

---

# Engineering Principles

This project intentionally follows several principles.

### Automate Desired State

If a change represents persistent desired configuration, it should eventually be automated.

```text
Infrastructure → Terraform

Host configuration → Ansible

Workloads → orchestration / deployment definitions

Application delivery → CI/CD
```

SSH remains useful for investigation and break-glass operations, not as the normal deployment mechanism.

---

### Understand Before Abstracting

New tooling is introduced only after experiencing the problem it solves.

Examples:

```text
Isolated Compose networks
        ↓
shared Docker network

Single-host limitations
        ↓
Swarm overlay networking

Manual container management
        ↓
desired-state services

Manual deployment
        ↓
CI/CD
```

---

### Break the Platform

Reliability cannot be learned only from successful deployments.

The platform is intentionally subjected to failures so recovery behavior can be observed and documented.

---

### Prefer Reproducibility Over Manual State

A system should be reproducible from source-controlled definitions.

Manual server configuration creates undocumented state and operational risk.

---

### Use the Simplest Tool That Solves the Problem

Not every workload requires Kubernetes.

Not every Compose problem requires Swarm.

Not every service requires multiple replicas.

Architecture should be driven by actual operational requirements rather than tool complexity.

---

# Security

Sensitive values are intentionally excluded from version control.

Do not commit:

```text
terraform.tfstate
terraform.tfstate.*
*.tfvars
.env
.env.*
API tokens
private SSH keys
registry credentials
CI/CD secrets
Ansible Vault passwords
```

`.terraform.lock.hcl` should remain committed so provider dependency versions are reproducible.

Example configuration files should use documentation/test values instead of real infrastructure credentials.

---

# Lab Timeline

## Completed

**August 29 – September 1, 2026**

- Repository architecture
- Terraform foundation
- DigitalOcean VPC
- Compute provisioning
- Least-privilege API permissions
- Cloud firewall
- Ansible configuration management
- Linux access model
- SSH hardening
- Docker installation
- Docker runtime fundamentals
- Docker bridge networking
- Docker DNS
- Compose network isolation
- Shared Compose networking
- Container immutability
- Swarm manager initialization
- Replicated services
- Desired-state reconciliation

## Planned

**September 2 – September 12, 2026**

- Swarm scaling
- Overlay networking
- Second node
- Multi-node scheduling
- Failure recovery
- Stateful workloads
- Rolling deployments
- Registry
- CI/CD
- Ingress
- Security
- Observability

**September 14 – September 16, 2026**

- Destroy infrastructure
- Rebuild from source control
- Complete architecture documentation
- Complete migration and operational runbooks
- Package the project as a portfolio case study

---

# What This Project Is Intended to Demonstrate

By completion, this repository should demonstrate the ability to:

- Provision reproducible cloud infrastructure
- Configure Linux systems safely
- Harden remote administrative access
- Understand Docker runtime behavior
- Troubleshoot container networking
- Migrate independent Compose workloads toward orchestration
- Build and operate a multi-node container platform
- Design for failure
- Perform rolling deployments
- Automate application delivery
- Introduce operational visibility
- Understand stateful versus stateless workload constraints
- Document platform architecture and recovery procedures

The end goal is not simply:

```text
"I know Terraform, Ansible and Docker."
```

It is:

> **Given a small production environment with containerized applications, I can audit the existing system, identify operational weaknesses, design a target architecture, automate the infrastructure, migrate workloads safely, test failure scenarios, and document how the platform is operated and recovered.**

---

## Status

🚧 **Active development**

This repository intentionally preserves the progression, experiments, failures and architectural decisions made while building the platform.
