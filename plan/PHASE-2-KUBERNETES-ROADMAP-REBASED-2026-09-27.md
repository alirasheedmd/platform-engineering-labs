# Phase 2 — Kubernetes Fundamentals Roadmap

**Project:** Platform Engineering Hands-On Lab  
**Phase:** 2 of 9  
**Focus:** Kubernetes Fundamentals  
**Primary Goal:** Rebuild the existing `lab-web` workload on Kubernetes and understand the core Kubernetes control model before moving into production patterns.

---

## 1. Phase Objective

Phase 1 established the infrastructure and orchestration foundation using:

- Terraform
- Ansible
- Linux hardening
- Docker
- Docker networking
- Docker Swarm
- Multi-node orchestration
- Failure recovery
- Stateful workloads
- Rolling deployments
- Private registry
- CI/CD
- Ingress/security fundamentals
- Observability basics
- Destroy/rebuild validation

Phase 2 builds directly on that foundation.

The goal is **not** to memorize `kubectl` commands.

The goal is to understand how Kubernetes represents desired state, schedules workloads, reconciles failures, provides networking and service discovery, rolls out application changes, and can be bootstrapped reproducibly using the same Infrastructure-as-Code approach used in Phase 1.

### End-state

By the end of Phase 2, the lab should support this workflow:

```text
Terraform
    ↓
Provision Linux VMs
    ↓
Ansible
    ↓
Configure Kubernetes prerequisites
    ↓
kubeadm
    ↓
Bootstrap Kubernetes cluster
    ↓
Install CNI
    ↓
Deploy lab-web
    ↓
Deployment + Service
    ↓
Scale / fail / recover / rollout
    ↓
Destroy
    ↓
Rebuild from Git
```

The final proof is simple:

> Destroy the Kubernetes lab completely and reproduce the working cluster and `lab-web` deployment from the repository.

---

# Phase 2 Milestone Calendar

**Phase 2 Start:** September 21, 2026  
**Last Updated:** October 2, 2026\
**Current Milestone:** Stage 2.10 — Scaling and Reconciliation

> The original target dates are preserved so the roadmap reflects the real engineering timeline. The revised dates below are the working schedule after time was diverted to another project. Stages 2.5–2.8 were reported complete by September 30; their exact completion days were not recorded here. Stage 2.9 was reported complete by October 2; its exact completion day was not recorded here.

| Stage | Milestone                            | Original Target | Revised / Actual Date         | Status         |
| ----- | ------------------------------------ | --------------- | ----------------------------- | -------------- |
| 2.0   | Freeze Phase 1                       | Sep 21, 2026    | Sep 21, 2026 — Actual         | ✅ Complete    |
| 2.1   | Kubernetes Architecture Fundamentals | Sep 21, 2026    | Sep 21, 2026 — Actual         | ✅ Complete    |
| 2.2   | Infrastructure for Kubernetes        | Sep 21–22, 2026 | Sep 22, 2026 — Actual         | ✅ Complete    |
| 2.3   | Linux + Kubernetes Prerequisites     | Sep 22, 2026    | Sep 23, 2026 — Actual         | ✅ Complete    |
| 2.4   | Bootstrap the Control Plane          | Sep 23, 2026    | Sep 24, 2026 — Actual         | ✅ Complete    |
| 2.5   | Install the CNI                      | Sep 23, 2026    | Sep 28 target; complete by Sep 30 | ✅ Complete |
| 2.6   | Join the Worker Node                 | Sep 23, 2026    | Sep 29 target; complete by Sep 30 | ✅ Complete |
| 2.7   | First Pod                            | Sep 24, 2026    | Sep 30 target; complete by Sep 30 | ✅ Complete |
| 2.8   | ReplicaSet                           | Sep 24, 2026    | Sep 30 target; complete by Sep 30 | ✅ Complete |
| 2.9   | Deployment                           | Sep 24, 2026    | Oct 1 target; complete by Oct 2 | ✅ Complete |
| 2.10  | Scaling and Reconciliation           | Sep 25, 2026    | Oct 2, 2026 — Revised Target  | ⬜ Planned     |
| 2.11  | Services                             | Sep 25, 2026    | Oct 3, 2026 — Revised Target  | ⬜ Planned     |
| 2.12  | Kubernetes DNS and Networking        | Sep 26, 2026    | Oct 4, 2026 — Revised Target  | ⬜ Planned     |
| 2.13  | Namespaces                           | Sep 26, 2026    | Oct 5, 2026 — Revised Target  | ⬜ Planned     |
| 2.14  | Labels, Selectors and Annotations    | Sep 27, 2026    | Oct 5, 2026 — Revised Target  | ⬜ Planned     |
| 2.15  | ConfigMaps                           | Sep 27, 2026    | Oct 6, 2026 — Revised Target  | ⬜ Planned     |
| 2.16  | Basic Secret Awareness               | Sep 27, 2026    | Oct 6, 2026 — Revised Target  | ⬜ Planned     |
| 2.17  | Image Updates and Rollouts           | Sep 28, 2026    | Oct 7, 2026 — Revised Target  | ⬜ Planned     |
| 2.18  | Node Failure Engineering             | Sep 29, 2026    | Oct 8, 2026 — Revised Target  | ⬜ Planned     |
| 2.19  | kubectl and API Inspection           | Sep 30, 2026    | Oct 9, 2026 — Revised Target  | ⬜ Planned     |
| 2.20  | Manifest Discipline                  | Sep 30, 2026    | Oct 9, 2026 — Revised Target  | ⬜ Planned     |
| 2.21  | Automate Cluster Bootstrap           | Oct 1, 2026     | Oct 10, 2026 — Revised Target | ⬜ Planned     |
| 2.22  | Destroy and Rebuild Test             | Oct 2, 2026     | Oct 11, 2026 — Revised Target | ⬜ Planned     |
| 2.23  | Documentation and Portfolio Proof    | Oct 3, 2026     | Oct 12, 2026 — Revised Target | ⬜ Planned     |

## Date Tracking Convention

For every milestone, keep four pieces of information:

```text
Original Target
    ↓
What the first plan expected

Revised Target
    ↓
The current working date after real-world schedule changes

Actual Date
    ↓
When the milestone was actually completed

Status
    ↓
Planned / In Progress / Blocked / Complete
```

Do not rewrite history when work moves. Preserve the original target, update the revised target, and add the actual completion date when the milestone is finished. The roadmap should show the real engineering timeline rather than an artificially perfect one.

---

# 2. Learning Philosophy

Phase 2 follows the same approach as Phase 1:

```text
Build
  ↓
Inspect
  ↓
Break
  ↓
Observe
  ↓
Recover
  ↓
Automate
  ↓
Destroy
  ↓
Rebuild
  ↓
Document
```

Every Kubernetes concept should answer four questions:

1. What problem does this object/component solve?
2. What desired state does it represent?
3. Which Kubernetes component reconciles it?
4. What happens when it fails?

Do not move forward merely because a command succeeded.

---

# 3. Scope

## In scope

Phase 2 covers:

- Kubernetes architecture
- Control plane fundamentals
- Worker-node fundamentals
- kubeadm
- kubelet
- containerd
- kubectl
- Kubernetes API
- etcd concept
- scheduler concept
- controller-manager concept
- CNI fundamentals
- Pods
- ReplicaSets
- Deployments
- Services
- CoreDNS
- Namespaces
- ConfigMaps
- basic Secret awareness
- labels
- selectors
- annotations
- scaling
- reconciliation
- basic rolling deployments
- rollback
- node failure
- Pod failure
- cluster inspection
- Terraform provisioning
- Ansible configuration
- kubeadm automation
- destroy/rebuild proof

## Explicitly out of scope

These belong primarily to **Phase 3 — Kubernetes Production Patterns**:

- Ingress controllers
- production TLS
- persistent storage architecture
- StorageClasses
- CSI drivers
- advanced Secrets management
- RBAC design
- ServiceAccounts beyond basic awareness
- liveness/readiness/startup probe design
- HPA
- VPA
- PDB
- topology spread constraints
- affinity / anti-affinity
- taints and tolerations
- production scheduling policies
- NetworkPolicy
- admission control
- Pod Security Standards
- Helm as an application packaging strategy
- advanced Kubernetes security

These belong to later phases:

- EKS / AKS / GKE
- Prometheus / Grafana / Loki
- OpenTelemetry
- Argo CD / Flux
- Internal Developer Platforms
- SLI / SLO engineering
- production cost engineering

---

# 4. Target Architecture

The initial Kubernetes lab will use two Linux nodes.

```text
                         Developer Mac
                              │
                           kubectl
                              │
                              ▼
                 Kubernetes API Server
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        │ DigitalOcean VPC                          │
        │                                           │
        │  platform-k8s-cp-01                       │
        │  ┌─────────────────────────────────────┐  │
        │  │ Control Plane                       │  │
        │  │                                     │  │
        │  │ kube-apiserver                      │  │
        │  │ etcd                                │  │
        │  │ kube-scheduler                      │  │
        │  │ kube-controller-manager             │  │
        │  │ kubelet                             │  │
        │  │ containerd                          │  │
        │  └─────────────────────────────────────┘  │
        │                    │                      │
        │                 CNI Network               │
        │                    │                      │
        │  platform-k8s-worker-01                   │
        │  ┌─────────────────────────────────────┐  │
        │  │ Worker Node                         │  │
        │  │                                     │  │
        │  │ kubelet                             │  │
        │  │ containerd                          │  │
        │  │ kube-proxy / networking components  │  │
        │  │                                     │  │
        │  │ lab-web Pods                        │  │
        │  └─────────────────────────────────────┘  │
        │                                           │
        └───────────────────────────────────────────┘
```

Initial topology:

| Node                     | Role          | Purpose                                       |
| ------------------------ | ------------- | --------------------------------------------- |
| `platform-k8s-cp-01`     | Control Plane | Kubernetes API and cluster control components |
| `platform-k8s-worker-01` | Worker        | Application workload execution                |

A second worker can be introduced later if useful for failure and scheduling exercises.

---

# 5. Swarm → Kubernetes Mental Model

Phase 2 should constantly compare Kubernetes with concepts already learned in Swarm.

| Docker Swarm           | Kubernetes            | Important Difference                                             |
| ---------------------- | --------------------- | ---------------------------------------------------------------- |
| Swarm cluster          | Kubernetes cluster    | Kubernetes exposes more independent control objects              |
| Manager                | Control Plane         | Kubernetes separates API, scheduler, controllers and datastore   |
| Worker                 | Worker Node           | Similar conceptual role                                          |
| Service                | Deployment + Service  | Compute reconciliation and network exposure are separate objects |
| Task                   | Pod instance          | Pod is Kubernetes' smallest deployable workload unit             |
| Replica count          | Deployment replicas   | ReplicaSet maintains Pod count                                   |
| Desired state          | Desired state         | Central Kubernetes design principle                              |
| Reconciliation         | Controllers           | Many specialized controllers reconcile different objects         |
| Overlay network        | CNI Pod network       | Networking is implemented through the CNI model                  |
| Routing mesh           | Service networking    | Kubernetes Services provide stable virtual endpoints             |
| Internal DNS           | CoreDNS + Service DNS | DNS is a first-class cluster service                             |
| Placement constraints  | Scheduling policies   | Kubernetes scheduling is significantly richer                    |
| Health checks          | Probes                | Covered properly in Phase 3                                      |
| Rolling service update | Deployment rollout    | Deployment manages ReplicaSets across revisions                  |
| Secret                 | Secret                | Production secret handling is deferred to Phase 3                |

---

# 6. Repository Strategy

Continue using the existing platform lab repository.

Suggested structure:

```text
platform-engineering-labs/
│
├── infrastructure/
│   └── terraform/
│       └── kubernetes/
│
├── configuration/
│   └── ansible/
│       ├── inventory/
│       ├── playbooks/
│       └── roles/
│           ├── common/
│           ├── kubernetes_common/
│           ├── kubernetes_control_plane/
│           └── kubernetes_worker/
│
├── kubernetes/
│   ├── namespaces/
│   ├── pods/
│   ├── deployments/
│   ├── services/
│   ├── configmaps/
│   └── lab-web/
│
├── applications/
│   └── lab-web/
│
├── scripts/
│   ├── bootstrap-k8s.sh
│   ├── reset-k8s.sh
│   └── verify-k8s.sh
│
├── docs/
│   └── phase-2-kubernetes/
│       ├── architecture.md
│       ├── failure-exercises.md
│       ├── rebuild-runbook.md
│       └── lessons-learned.md
│
└── PHASE-2-KUBERNETES-ROADMAP.md
```

Do not over-engineer the repository at the beginning.

Refactor only after repetition reveals a useful abstraction.

---

# 7. Phase 2 Milestones

---

## Stage 2.0 — Freeze Phase 1

**Date:** September 21, 2026 — Actual  
**Status:** ✅ Complete

### Objective

Preserve the completed Swarm lab before Kubernetes work changes the repository.

### Tasks

- Ensure the working tree is clean.
- Commit outstanding Phase 1 documentation.
- Tag the completed Swarm state.
- Push the tag.
- Create a Kubernetes phase branch.

Suggested tag:

```text
phase-1-swarm-complete
```

Suggested branch:

```text
phase-2-kubernetes
```

### Exit criteria

- Phase 1 can be checked out independently.
- Kubernetes work begins from a known Git state.
- Existing Swarm material remains intact.

---

# Stage 2.1 — Kubernetes Architecture Fundamentals

**Date:** September 21, 2026 — Actual  
**Status:** ✅ Complete

## Objective

Understand what Kubernetes actually is before installing it.

## Topics

Study the responsibilities of:

### Control plane

- kube-apiserver
- etcd
- kube-scheduler
- kube-controller-manager

### Node components

- kubelet
- container runtime
- kube-proxy / networking layer

### Core concepts

- declarative desired state
- Kubernetes API
- API objects
- reconciliation loops
- controllers
- labels
- selectors
- object metadata
- spec vs status

## Key mental model

```text
User declares desired state
          ↓
     API Server
          ↓
        etcd
          ↓
      Controllers
          ↓
      Scheduler
          ↓
       kubelet
          ↓
      containerd
          ↓
        Pods
```

## Exercises

Be able to explain:

1. Why Kubernetes needs an API server.
2. Why etcd exists.
3. Why the scheduler does not start containers itself.
4. Why kubelet runs on every node.
5. What reconciliation means.
6. Why `spec` and `status` are separate.
7. Why Kubernetes is API-driven.

## Exit criteria

Without notes, explain:

> What happens inside Kubernetes from the moment a Deployment with three replicas is submitted until three running Pods exist?

Do not continue until this flow is clear.

---

# Stage 2.2 — Infrastructure for Kubernetes

**Date:** September 21–22, 2026 — Actual  
**Status:** ✅ Complete

## Objective

Provision Kubernetes nodes using Terraform.

## Tasks

Create/reuse Terraform for:

```text
platform-k8s-cp-01
platform-k8s-worker-01
```

Configure:

- VPC attachment
- private networking
- SSH access
- firewall rules
- node tags
- Terraform outputs

Outputs should include:

- control-plane public IP
- control-plane private IP
- worker public IP
- worker private IP
- VPC ID

## Validation

Verify:

```bash
terraform plan
terraform apply
terraform output
```

Then verify:

- SSH connectivity
- private-IP connectivity
- correct CPU/RAM sizing
- correct hostname
- expected network interfaces

## Exit criteria

Infrastructure is fully reproducible through Terraform.

No manually created cloud VM should be required.

---

# Stage 2.3 — Linux + Kubernetes Prerequisites

**Original Target:** September 22, 2026  
**Actual Completion:** September 23, 2026  
**Status:** ✅ Complete

## Objective

Configure nodes consistently through Ansible.

## Tasks

Automate:

- hostname configuration
- package updates
- required kernel modules
- sysctl networking settings
- swap configuration
- containerd installation
- containerd configuration
- Kubernetes package repository
- kubeadm
- kubelet
- kubectl where appropriate
- package version pinning

## Concepts

Understand why Kubernetes cares about:

- swap
- cgroups
- kernel forwarding
- bridge traffic
- CRI
- container runtime configuration

## Validation

Check:

```bash
containerd --version
kubeadm version
kubelet --version
```

Inspect:

```bash
systemctl status containerd
systemctl status kubelet
```

The kubelet may not become fully healthy until the node joins a cluster.

Understand why.

## Exit criteria

Running Ansible twice should be idempotent.

Expected pattern:

```text
First run  → changes applied
Second run → little or no change
```

---

# Stage 2.4 — Bootstrap the Control Plane

**Original Target:** September 23, 2026  
**Actual Completion:** September 24, 2026  
**Status:** ✅ Complete

## Objective

Create the Kubernetes control plane using kubeadm.

## Tasks

Use `kubeadm init`.

Configure deliberately:

- control-plane private address
- Pod CIDR if required by selected CNI
- cluster endpoint assumptions
- certificate behavior
- kubeconfig

After initialization:

- obtain admin kubeconfig
- configure `kubectl`
- inspect cluster state

## Commands to understand

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
kubectl get componentstatuses
```

Where deprecated commands exist, understand the modern replacement rather than relying on memorized commands.

## Questions

Be able to explain:

- What did `kubeadm init` actually create?
- Where does kubeconfig point?
- Why is the node initially `NotReady`?
- What Kubernetes services are running?
- Which components are static Pods?

## Exit criteria

The control plane exists and `kubectl` can communicate with it.

---

# Stage 2.5 — Install the CNI

**Original Target:** September 23, 2026  
**Actual Start:** September 24, 2026  
**Revised Target:** September 28, 2026  
**Actual Completion:** By September 30, 2026 (exact day not recorded)  
**Status:** ✅ Complete

## Objective

Make Pod networking functional.

## Concepts

Understand:

- Kubernetes itself does not implement the entire Pod network.
- CNI provides the networking implementation.
- Every Pod receives an IP.
- Pods are expected to communicate through the cluster network.
- Service networking is different from Pod networking.

## Tasks

Flannel was selected for the lab; its manifest and supporting configuration are in the repository.

Keep the first implementation simple.

The tracked manifest is `configuration/kubernetes/networking/flannel/kube-flannel-v0.28.9.yml`.

## Validation

```bash
kubectl get nodes
kubectl get pods -A
```

Control-plane node should transition to:

```text
Ready
```

Inspect CNI-related Pods.

## Exit criteria

- node is Ready
- system Pods are healthy
- Pod networking is functional

---

# Stage 2.6 — Join the Worker Node

**Original Target:** September 23, 2026  
**Revised Target:** September 29, 2026  
**Actual Completion:** By September 30, 2026 (exact day not recorded)  
**Status:** ✅ Complete

## Objective

Create the first real multi-node Kubernetes cluster.

## Tasks

Generate/obtain a kubeadm join command.

Join:

```text
platform-k8s-worker-01
```

Validate:

```bash
kubectl get nodes -o wide
```

Expected logical result:

```text
platform-k8s-cp-01       Ready
platform-k8s-worker-01   Ready
```

## Inspect

```bash
kubectl describe node platform-k8s-worker-01
```

Study:

- labels
- addresses
- capacity
- allocatable resources
- conditions
- kubelet version
- runtime
- Pod CIDR

## Exit criteria

Two-node cluster is healthy and both nodes are Ready.

---

# Stage 2.7 — First Pod

**Original Target:** September 24, 2026  
**Revised Target:** September 30, 2026  
**Actual Completion:** By September 30, 2026 (exact day not recorded)  
**Status:** ✅ Complete

## Objective

Understand the smallest Kubernetes workload object before using Deployments.

Deploy `lab-web` as a raw Pod.

Example conceptual manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lab-web
  labels:
    app: lab-web
spec:
  containers:
    - name: lab-web
      image: ghcr.io/alirasheedmd/platform-lab-web:<version>
```

## Commands

Practice:

```bash
kubectl apply -f ...
kubectl get pods
kubectl get pods -o wide
kubectl describe pod ...
kubectl logs ...
kubectl exec ...
kubectl delete pod ...
```

## Failure exercise

Delete the raw Pod.

Observe:

```text
Pod disappears.
Nothing recreates it.
```

This is intentional.

## Lesson

A raw Pod does not provide the reconciliation behavior required for an application workload.

## Exit criteria

Understand why production application workloads should generally not be modeled as standalone Pods.

---

# Stage 2.8 — ReplicaSet

**Original Target:** September 24, 2026  
**Revised Target:** September 30, 2026  
**Actual Completion:** By September 30, 2026 (exact day not recorded)  
**Status:** ✅ Complete

## Objective

Understand replica reconciliation.

Create a ReplicaSet for `lab-web`.

Manifest: `configuration/kubernetes/lab-web/replicaset.yaml`.

Desired state:

```text
replicas: 3
```

## Exercises

Observe:

```bash
kubectl get rs
kubectl get pods
```

Delete one Pod.

Observe the ReplicaSet create another.

Then deliberately create/delete Pods and watch reconciliation.

## Mental model

```text
Desired Pods = 3
Actual Pods  = 2

ReplicaSet Controller
        ↓
Creates 1 Pod
        ↓
Actual Pods = 3
```

## Exit criteria

Be able to explain:

> Why did the Pod return this time when it did not return in the raw-Pod exercise?

---

# Stage 2.9 — Deployment

**Original Target:** September 24, 2026  
**Revised Target:** October 1, 2026  
**Actual Completion:** By October 2, 2026 (exact day not recorded)\
**Status:** ✅ Complete

Repository artifact: `configuration/kubernetes/lab-web/deployment.yaml` defines the `lab-web` Deployment with three replicas.

## Objective

Move to the normal stateless application workload abstraction.

Create:

```text
Deployment
    ↓
ReplicaSet
    ↓
Pods
```

## Exercises

Inspect relationships:

```bash
kubectl get deployments
kubectl get rs
kubectl get pods
```

Use labels to trace ownership.

Study:

```bash
kubectl describe deployment lab-web
kubectl describe rs ...
```

## Concepts

Understand:

- Deployment
- ReplicaSet
- Pod ownership
- desired replicas
- template
- revision
- controller hierarchy

## Exit criteria

`lab-web` runs as a Deployment with multiple replicas.

---

# Stage 2.10 — Scaling and Reconciliation

**Original Target:** September 25, 2026  
**Revised Target:** October 2, 2026  
**Status:** ⬜ Planned

## Objective

Repeat the Swarm scaling exercises in Kubernetes.

Perform:

```text
1 → 3 → 6 → 2
```

Example:

```bash
kubectl scale deployment lab-web --replicas=6
```

Inspect where Pods are scheduled.

## Failure exercises

1. Delete one Pod.
2. Delete several Pods.
3. Restart container runtime on worker.
4. Stop kubelet temporarily.
5. Recover services.

Observe:

- desired state
- actual state
- rescheduling behavior
- Pod lifecycle
- node conditions
- event history

## Commands

Use:

```bash
kubectl get pods -w
kubectl get events
kubectl describe pod ...
kubectl describe node ...
```

## Exit criteria

You can explain Kubernetes reconciliation using evidence from your own failure tests.

---

# Stage 2.11 — Services

**Original Target:** September 25, 2026  
**Revised Target:** October 3, 2026  
**Status:** ⬜ Planned

## Objective

Understand why Pods should not be addressed directly.

## Problem

Pod IP addresses are ephemeral.

A replacement Pod may have a new IP.

Therefore applications need a stable abstraction.

## Build

Create a Kubernetes Service for:

```text
lab-web
```

Begin with:

```text
ClusterIP
```

## Concepts

Understand:

- Service
- ClusterIP
- endpoints / EndpointSlices
- label selector
- stable virtual IP
- stable DNS name

## Exercises

Inspect:

```bash
kubectl get svc
kubectl describe svc lab-web
kubectl get endpointslices
```

Delete Pods and prove that the Service remains stable.

## Exit criteria

`lab-web` is reachable through a stable Service even as Pods are recreated.

---

# Stage 2.12 — Kubernetes DNS and Networking

**Original Target:** September 26, 2026  
**Revised Target:** October 4, 2026  
**Status:** ⬜ Planned

## Objective

Understand Pod and Service communication.

## Topics

Study:

```text
Pod → Pod
Pod → Service
Service → Pod
DNS → Service
```

Deploy a temporary diagnostic Pod.

Test:

```bash
nslookup lab-web
wget/curl lab-web
```

Observe DNS naming.

Example concept:

```text
lab-web.<namespace>.svc.cluster.local
```

## Exercises

Inspect:

- Pod IPs
- Service IP
- DNS resolution
- EndpointSlices
- traffic distribution

Delete one backend Pod and repeat requests.

## Exit criteria

Understand the difference between:

- Pod IP
- Service IP
- DNS name
- node IP

---

# Stage 2.13 — Namespaces

**Original Target:** September 26, 2026  
**Revised Target:** October 5, 2026  
**Status:** ⬜ Planned

## Objective

Introduce basic logical separation.

Create:

```text
platform-lab
```

Move the lab workload into that namespace.

## Commands

Practice:

```bash
kubectl create namespace platform-lab
kubectl get all -n platform-lab
kubectl config set-context --current --namespace=platform-lab
```

## Concepts

Understand:

- namespace scope
- cluster-scoped resources
- namespaced resources
- same object names in different namespaces

## Exit criteria

All Phase 2 application resources live inside a deliberate namespace.

---

# Stage 2.14 — Labels, Selectors and Annotations

**Original Target:** September 27, 2026  
**Revised Target:** October 5, 2026  
**Status:** ⬜ Planned

## Objective

Understand one of Kubernetes' most important organizational mechanisms.

Example labels:

```yaml
labels:
  app: lab-web
  environment: lab
  component: frontend
```

## Exercises

Query:

```bash
kubectl get pods -l app=lab-web
kubectl get pods -l environment=lab
```

Understand how Services and Deployments rely on selectors.

## Critical lesson

A selector error can create healthy Pods that receive no Service traffic.

Reproduce this intentionally.

Change the Service selector so it matches no Pods.

Inspect the failure.

Then repair it.

## Exit criteria

Understand the operational role of labels beyond simple organization.

---

# Stage 2.15 — ConfigMaps

**Original Target:** September 27, 2026  
**Revised Target:** October 6, 2026  
**Status:** ⬜ Planned

## Objective

Separate configuration from the container image.

Create configuration for `lab-web` using a ConfigMap.

Explore:

- environment variable injection
- mounted configuration

Do not introduce complex configuration-management tooling yet.

## Concepts

Understand the difference between:

```text
Image
Configuration
Runtime state
```

## Failure exercise

Change configuration.

Observe whether:

- existing Pods change automatically
- Pods require restart
- mounted data behaves differently from environment variables

## Exit criteria

Application configuration no longer has to be baked into the image.

---

# Stage 2.16 — Basic Secret Awareness

**Original Target:** September 27, 2026  
**Revised Target:** October 6, 2026  
**Status:** ⬜ Planned

## Objective

Understand the Kubernetes Secret object without treating it as production-grade secret management.

Create a harmless lab value.

Study:

- Secret object
- base64 representation
- environment injection
- mounted Secret
- visibility considerations

## Important rule

Do not store real credentials in the public repository.

Production-grade secret management belongs to Phase 3 and later security work.

## Exit criteria

Understand what Kubernetes Secrets do and, equally importantly, what they do **not** guarantee by themselves.

---

# Stage 2.17 — Image Updates and Rollouts

**Original Target:** September 28, 2026  
**Revised Target:** October 7, 2026  
**Status:** ⬜ Planned

## Objective

Recreate the immutable deployment workflow from Phase 1 using Kubernetes.

Deploy:

```text
lab-web:v1
```

Then update to:

```text
lab-web:v2
```

Observe:

```bash
kubectl rollout status deployment/lab-web
kubectl rollout history deployment/lab-web
```

Inspect:

```text
Deployment
   ↓
old ReplicaSet
new ReplicaSet
   ↓
Pods
```

## Failure exercise

Deploy a deliberately invalid image tag.

Observe:

- new ReplicaSet
- failing Pods
- old workload behavior
- rollout state
- Events

Then rollback:

```bash
kubectl rollout undo deployment/lab-web
```

## Exit criteria

Successfully demonstrate:

```text
Deploy
  ↓
Rollout
  ↓
Failure
  ↓
Inspect
  ↓
Rollback
```

---

# Stage 2.18 — Node Failure Engineering

**Original Target:** September 29, 2026  
**Revised Target:** October 8, 2026  
**Status:** ⬜ Planned

## Objective

Understand Kubernetes behavior during node degradation.

## Exercises

### Exercise 1

Stop kubelet on the worker.

Observe:

```bash
kubectl get nodes
kubectl get pods -o wide
kubectl get events
```

### Exercise 2

Stop containerd.

Observe workload behavior.

### Exercise 3

Shut down the worker VM.

Watch node conditions and Pod state.

### Exercise 4

Restore the worker.

Observe recovery.

## Questions

Document:

- How quickly did Kubernetes detect the failure?
- What happened to existing Pods?
- Were Pods recreated elsewhere?
- Did the one-worker topology constrain recovery?
- How would another worker change the result?

This is a useful point to consider adding:

```text
platform-k8s-worker-02
```

for stronger scheduling/failure experiments.

## Exit criteria

Produce a short failure report containing actual observations, not just expected Kubernetes behavior.

---

# Stage 2.19 — kubectl and API Inspection

**Original Target:** September 30, 2026  
**Revised Target:** October 9, 2026  
**Status:** ⬜ Planned

## Objective

Stop treating `kubectl` as magic.

Understand that it is primarily a Kubernetes API client.

## Explore

```bash
kubectl api-resources
kubectl api-versions
kubectl explain pod
kubectl explain deployment
kubectl explain deployment.spec
```

Inspect raw object representation:

```bash
kubectl get deployment lab-web -o yaml
kubectl get pod <pod> -o yaml
```

Identify:

```text
apiVersion
kind
metadata
spec
status
```

Study:

- resourceVersion
- generation
- observedGeneration
- ownerReferences
- UID
- creationTimestamp

## Exit criteria

Be able to navigate an unfamiliar Kubernetes resource using the API schema instead of searching blindly for example YAML.

---

# Stage 2.20 — Manifest Discipline

**Original Target:** September 30, 2026  
**Revised Target:** October 9, 2026  
**Status:** ⬜ Planned

## Objective

Move from imperative experimentation to repository-managed declarative state.

By this stage, important resources should exist as YAML manifests.

Suggested layout:

```text
kubernetes/lab-web/
├── namespace.yaml
├── configmap.yaml
├── deployment.yaml
└── service.yaml
```

Apply:

```bash
kubectl apply -f kubernetes/lab-web/
```

Delete:

```bash
kubectl delete -f kubernetes/lab-web/
```

Reapply.

## Exit criteria

The workload can be recreated from Git without manually reconstructing Kubernetes objects.

---

# Stage 2.21 — Automate Cluster Bootstrap

**Original Target:** October 1, 2026  
**Revised Target:** October 10, 2026  
**Status:** ⬜ Planned

## Objective

Reduce manual cluster setup.

Build automation around:

```text
Terraform
    ↓
Ansible
    ↓
kubeadm init
    ↓
CNI install
    ↓
worker join
    ↓
workload deployment
```

Suggested entry point:

```bash
./scripts/bootstrap-k8s.sh
```

The script should orchestrate existing tools rather than contain hundreds of opaque shell commands.

Good:

```text
Terraform handles infrastructure.
Ansible handles node configuration.
kubeadm handles Kubernetes bootstrap.
kubectl applies Kubernetes objects.
```

Avoid:

```text
one giant Bash script that replaces all tools
```

## Exit criteria

The cluster can be created with a small documented sequence of commands.

---

# Stage 2.22 — Destroy and Rebuild Test

**Original Target:** October 2, 2026  
**Revised Target:** October 11, 2026  
**Status:** ⬜ Planned

## Objective

Prove that Git contains the system knowledge, not your memory.

## Test

Destroy the entire lab.

```bash
terraform destroy
```

Then rebuild using repository instructions only.

Expected progression:

```text
Git clone
   ↓
Terraform init/apply
   ↓
Ansible configuration
   ↓
Kubernetes bootstrap
   ↓
CNI
   ↓
worker join
   ↓
kubectl apply
   ↓
lab-web running
```

## Rules

During rebuild:

- do not manually repair undocumented steps
- record every failure
- convert required fixes into code/documentation
- rerun until repeatable

## Exit criteria

A fresh environment can reproduce the Kubernetes lab from Git.

---

# Stage 2.23 — Documentation and Portfolio Proof

**Original Target:** October 3, 2026  
**Revised Target:** October 12, 2026  
**Status:** ⬜ Planned

## Objective

Turn the lab into evidence of engineering ability.

Create:

### Architecture document

Explain:

- infrastructure
- control plane
- workers
- network
- workloads
- Service path
- provisioning path

### Kubernetes migration document

Compare:

```text
Swarm implementation
        ↓
Kubernetes implementation
```

### Failure report

Document:

- Pod deletion
- Replica reconciliation
- runtime failure
- kubelet failure
- node failure
- bad rollout
- rollback

### Rebuild runbook

Someone unfamiliar with the lab should be able to reproduce it.

### README

Include:

- problem
- architecture
- tools
- deployment
- failures tested
- screenshots/terminal evidence
- lessons learned

---

# 8. Phase 2 Validation Matrix

Before declaring Phase 2 complete, verify every item.

## Infrastructure

- [ ] Kubernetes infrastructure is Terraform-managed.
- [ ] Control-plane node can be recreated.
- [ ] Worker node can be recreated.
- [ ] Firewall rules are documented.
- [ ] VPC/private networking is documented.

## Configuration Management

- [ ] Kubernetes prerequisites are Ansible-managed.
- [ ] containerd is configured through automation.
- [ ] kubeadm/kubelet packages are version controlled/pinned.
- [ ] Ansible is idempotent.

## Cluster

- [ ] Control plane successfully bootstraps.
- [ ] CNI is installed.
- [ ] Worker successfully joins.
- [ ] All required nodes become Ready.
- [ ] kubeconfig access is documented.

## Kubernetes API

- [ ] Understand `apiVersion`.
- [ ] Understand `kind`.
- [ ] Understand `metadata`.
- [ ] Understand `spec`.
- [ ] Understand `status`.
- [ ] Can inspect unfamiliar resources using `kubectl explain`.

## Workloads

- [ ] Raw Pod deployed.
- [ ] Raw Pod deletion behavior observed.
- [ ] ReplicaSet deployed.
- [ ] Replica reconciliation tested.
- [ ] Deployment deployed.
- [ ] Deployment ownership hierarchy understood.

## Scaling

- [ ] Scale to 1.
- [ ] Scale to 3.
- [ ] Scale to 6.
- [ ] Scale back to 2.
- [ ] Pod placement inspected.

## Networking

- [ ] Pod IP behavior understood.
- [ ] Service created.
- [ ] ClusterIP understood.
- [ ] Service survives Pod replacement.
- [ ] CoreDNS resolution tested.
- [ ] Service selector failure deliberately reproduced.

## Configuration

- [ ] Namespace created.
- [ ] Labels used intentionally.
- [ ] Selectors understood.
- [ ] ConfigMap used.
- [ ] Basic Secret object tested without real credentials.

## Deployments

- [ ] New image deployed.
- [ ] Rollout observed.
- [ ] Rollout history inspected.
- [ ] Broken image deliberately deployed.
- [ ] Failure inspected through Events/status.
- [ ] Deployment successfully rolled back.

## Failure Engineering

- [ ] Pod killed.
- [ ] Multiple Pods killed.
- [ ] kubelet stopped.
- [ ] containerd stopped.
- [ ] Worker failure simulated.
- [ ] Recovery behavior documented.

## Reproducibility

- [ ] Cluster destroyed.
- [ ] Infrastructure rebuilt.
- [ ] Nodes reconfigured.
- [ ] Kubernetes reinitialized.
- [ ] Worker rejoined.
- [ ] Workload redeployed.
- [ ] No undocumented manual dependency remained.

## Documentation

- [ ] Architecture diagram.
- [ ] Swarm-to-Kubernetes comparison.
- [ ] Failure report.
- [ ] Rebuild runbook.
- [ ] README updated.
- [ ] Portfolio screenshots/evidence captured.

---

# 9. Phase 2 Completion Definition

Phase 2 is complete only when all of the following are true.

You can explain the following without relying on memorized definitions:

### Architecture

```text
kubectl
   ↓
API Server
   ↓
etcd
   ↓
Controllers / Scheduler
   ↓
kubelet
   ↓
containerd
   ↓
Pods
```

### Application ownership

```text
Deployment
    ↓
ReplicaSet
    ↓
Pods
```

### Application networking

```text
Client Pod
    ↓
CoreDNS
    ↓
Service
    ↓
EndpointSlice
    ↓
lab-web Pods
```

### Reconciliation

```text
Desired state
     ↓
Controller compares
     ↓
Actual state
     ↓
Difference detected
     ↓
Corrective action
```

### Infrastructure lifecycle

```text
Terraform
    ↓
Ansible
    ↓
kubeadm
    ↓
Kubernetes
    ↓
Manifests
    ↓
lab-web
```

And most importantly:

> You can destroy the cluster and reproduce it from the repository without depending on memory.

---

# 10. Phase 2 Deliverables

At completion, the repository should contain evidence for the following:

1. Terraform-managed Kubernetes infrastructure.
2. Ansible-managed Kubernetes node configuration.
3. kubeadm-based control plane.
4. At least one worker node.
5. Working CNI.
6. `lab-web` Kubernetes Deployment.
7. `lab-web` Kubernetes Service.
8. ConfigMap-based configuration.
9. Versioned image rollout.
10. Failed rollout demonstration.
11. Successful rollback.
12. Pod failure demonstration.
13. Worker failure demonstration.
14. Kubernetes manifests stored in Git.
15. Destroy/rebuild proof.
16. Architecture documentation.
17. Failure engineering report.
18. Rebuild runbook.
19. Swarm-to-Kubernetes comparison.
20. Portfolio-ready README evidence.

---

# 11. What We Should Be Able to Say After Phase 2

At the end of the phase, the technical narrative should be:

> I first built the workload using Docker and Docker Swarm so I could understand container networking, desired state, scheduling, reconciliation and failure recovery without hiding those concepts behind Kubernetes.
>
> I then rebuilt the same workload on a kubeadm-based Kubernetes cluster. I provisioned the infrastructure through Terraform, configured the nodes through Ansible, used containerd as the runtime, installed cluster networking, joined worker nodes, and migrated the application to Deployments and Services.
>
> I tested replica reconciliation, scaling, Pod failure, node failure, DNS/service discovery, image rollouts and rollback. Finally, I destroyed the environment and rebuilt it from the repository to prove that the system was reproducible rather than dependent on manual configuration.

That is substantially stronger than:

> "I completed a Kubernetes tutorial."

---

# 12. Transition to Phase 3

Do not begin Phase 3 until the Phase 2 completion criteria are satisfied.

Phase 3 will transform the working Kubernetes cluster into a more production-oriented platform by introducing:

```text
Ingress
Storage
RBAC
Secrets
Probes
HPA
PDB
Advanced scheduling
Security controls
```

The distinction matters:

```text
Phase 2
"How Kubernetes works"

        ↓

Phase 3
"How to operate Kubernetes workloads properly in production"
```

---

# 13. Overall Program Position

```text
Phase 1
Docker + Swarm Foundation
        ↓
        COMPLETE

Phase 2
Kubernetes Fundamentals
        ↓
        CURRENT

Phase 3
Kubernetes Production Patterns
        ↓

Phase 4
Cloud-Managed Kubernetes
EKS / AKS / GKE
        ↓

Phase 5
Observability
Prometheus / Grafana / Loki / OpenTelemetry
        ↓

Phase 6
GitOps
Argo CD / Flux
        ↓

Phase 7
Platform Engineering
Self-service / Golden Paths / IaC Modules / Platform APIs
        ↓

Phase 8
Production & SRE Depth
SLI / SLO / Incidents / Capacity / Reliability / Cost / Security
        ↓

Phase 9
Portfolio-Grade Production System
```

---

## Guiding Rule

Throughout Phase 2:

> Do not optimize for completing Kubernetes topics quickly. Optimize for being able to explain what the cluster did, why it did it, how you proved it, and how you would reproduce it.
