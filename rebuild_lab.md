# Phase 2 Kubernetes Lab Rebuild Runbook

## Purpose

This runbook restores the Kubernetes lab from a destroyed environment using the repository as the source of truth.

The procedure has been checked against repository paths and configuration; a clean destroy/rebuild has not yet been verified.

**Last updated:** October 2, 2026

**Workload checkpoint:** Stage 2.9 — Deployment (`lab-web`, three replicas in the `default` namespace).

The target sequence is:

```text
Terraform
   ↓
Provision VMs + VPC + firewall
   ↓
Bootstrap SSH/platform access
   ↓
Ansible Kubernetes prerequisites
   ↓
kubeadm control plane
   ↓
Flannel CNI
   ↓
Worker join
   ↓
GHCR pull credentials
   ↓
Kubernetes workload
   ↓
Validation
```

The rule for this runbook is:

> If rebuilding the lab requires a command that is not documented here or encoded in the repository, record it and convert it into automation or documentation.

---

# 1. Prerequisites

Run repository-side commands from:

```bash
cd ~/Learning/platform-lab
```

Required local tools:

```bash
terraform version
ansible --version
ssh -V
git --version
```

Confirm branch:

```bash
git branch --show-current
```

Expected:

```text
phase-2-kubernetes
```

Pull the latest committed state:

```bash
git pull
```

---

# 2. Provision Infrastructure

Move to the Kubernetes Terraform directory:

```bash
cd infrastructure/terraform
```

Initialize Terraform:

```bash
terraform init
```

Review:

```bash
terraform plan
```

Provision:

```bash
terraform apply
```

Return to repository root:

```bash
cd ../..
```

## Expected infrastructure

Two Ubuntu nodes:

```text
platform-k8s-cp-01
platform-k8s-worker-01
```

Example private IPs from the current lab:

```text
Control plane: 10.20.0.3
Worker:        10.20.0.2
```

Public and private IPs may change after a rebuild. Read the current addresses with `terraform -chdir=infrastructure/terraform output` from the repository root. Replace every example IP below, including the worker JoinConfiguration, with the actual Terraform output; verify it against the regenerated inventory.

The DigitalOcean firewall should include the Kubernetes and Flannel requirements already defined by Terraform, including Flannel VXLAN traffic:

```text
UDP 8472
Source: 10.20.0.0/24
```

---

# 3. Bootstrap Node Access

From repository root:

```bash
./scripts/bootstrap-k8s.sh
```

This prepares SSH/platform-user access and regenerates the Ansible inventory for the current Terraform infrastructure.

Expected final result:

```text
platform-k8s-worker-01 | SUCCESS
platform-k8s-cp-01     | SUCCESS
```

Verify inventory:

```bash
cat configuration/ansible/inventory.ini
```

Confirm:

```text
platform-k8s-cp-01     k8s_private_ip=10.20.0.3
platform-k8s-worker-01 k8s_private_ip=10.20.0.2
```

The `ansible_host` public addresses may be different on every rebuild.

---

# 4. Configure Kubernetes Prerequisites

Run:

```bash
(
  cd configuration/ansible &&
  ansible-playbook \
    -u platform \
    playbooks/k8s-prerequisites.yml
)
```

This configures both nodes with the Kubernetes prerequisites, including:

```text
swap configuration
br_netfilter
vxlan
IP forwarding
bridge netfilter settings
containerd
systemd cgroups
kubeadm
kubelet
kubectl
Kubernetes package pinning
```

## Idempotency check

Run the same playbook again:

```bash
(
  cd configuration/ansible &&
  ansible-playbook \
    -u platform \
    playbooks/k8s-prerequisites.yml
)
```

The second run should show little or no unnecessary change.

---

# 5. Bootstrap the Control Plane

Run:

```bash
(
  cd configuration/ansible &&
  ansible-playbook \
    -u platform \
    playbooks/k8s-control-plane.yml
)
```

This should:

```text
render kubeadm configuration
        ↓
validate kubeadm configuration
        ↓
run preflight checks
        ↓
kubeadm init
        ↓
create /etc/kubernetes/admin.conf
        ↓
configure /home/platform/.kube/config
```

Do not manually copy `admin.conf`.

That is now Ansible-managed.

---

# 6. Verify kubectl Access

SSH into the control plane:

```bash
ssh platform@<CONTROL_PLANE_PUBLIC_IP>
```

Run without `sudo`:

```bash
kubectl get nodes
```

Before the CNI is installed, the control-plane node may show:

```text
NotReady
```

That is expected because Pod networking has not yet been configured.

Verify system Pods:

```bash
kubectl get pods -A
```

Exit back to the local machine when needed:

```bash
exit
```

---

# 7. Install Flannel CNI

The repository contains the pinned Flannel manifest:

```text
configuration/kubernetes/networking/flannel/kube-flannel-v0.28.9.yml
```

The manifest is configured to use the Kubernetes private interface:

```text
eth1
```

This ensures Flannel uses:

```text
10.20.0.x
```

instead of the public network interface.

Copy the manifest to the control plane:

```bash
scp \
  configuration/kubernetes/networking/flannel/kube-flannel-v0.28.9.yml \
  platform@<CONTROL_PLANE_PUBLIC_IP>:/tmp/kube-flannel-v0.28.9.yml
```

SSH to the control plane:

```bash
ssh platform@<CONTROL_PLANE_PUBLIC_IP>
```

Apply:

```bash
kubectl apply -f /tmp/kube-flannel-v0.28.9.yml
```

Verify:

```bash
kubectl get pods -n kube-flannel
kubectl get nodes
kubectl get pods -A
```

Expected control-plane status:

```text
Ready
```

Expected initial Flannel state:

```text
DESIRED 1
READY   1
```

---

# 8. Join the Worker Node

Worker join is currently a documented manual step.

Full automation is deferred to the Kubernetes bootstrap automation stage.

## 8.1 Generate a fresh bootstrap token

On the control plane:

```bash
sudo kubeadm token create --print-join-command
```

This returns:

```text
API endpoint
bootstrap token
CA certificate hash
```

Do not commit the token to Git.

Do not store the token in the repository.

---

## 8.2 Create temporary JoinConfiguration

On the local machine create:

```text
/tmp/kubeadm-join.yaml
```

Use:

```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration

discovery:
  bootstrapToken:
    apiServerEndpoint: "10.20.0.3:6443"
    token: "<CURRENT_BOOTSTRAP_TOKEN>"
    caCertHashes:
      - "sha256:<CURRENT_CA_HASH>"

nodeRegistration:
  name: "platform-k8s-worker-01"
  criSocket: "unix:///run/containerd/containerd.sock"
  kubeletExtraArgs:
    - name: node-ip
      value: "10.20.0.2"
```

The explicit node IP is important because the VM has multiple network interfaces.

Kubernetes should register the worker with:

```text
InternalIP: 10.20.0.2
```

---

## 8.3 Copy configuration to worker

From repository root:

```bash
(
  cd configuration/ansible &&
  ansible k8s_workers \
    -u platform \
    -b \
    -m copy \
    -a 'src=/tmp/kubeadm-join.yaml dest=/tmp/kubeadm-join.yaml mode=0600'
)
```

---

## 8.4 Validate before joining

```bash
(
  cd configuration/ansible &&
  ansible k8s_workers \
    -u platform \
    -b \
    -m command \
    -a 'kubeadm config validate --config /tmp/kubeadm-join.yaml'
)
```

Expected:

```text
ok
```

Do not continue if validation fails.

---

## 8.5 Join worker

```bash
(
  cd configuration/ansible &&
  ansible k8s_workers \
    -u platform \
    -b \
    -m command \
    -a 'kubeadm join --config /tmp/kubeadm-join.yaml'
)
```

---

# 9. Verify Multi-Node Cluster

On the control plane:

```bash
kubectl get nodes -o wide
```

Expected:

```text
platform-k8s-cp-01       Ready   control-plane   ...   10.20.0.3
platform-k8s-worker-01   Ready   <none>          ...   10.20.0.2
```

Verify Flannel:

```bash
kubectl get daemonset -n kube-flannel
```

Expected:

```text
DESIRED   CURRENT   READY
2         2         2
```

Verify cluster Pods:

```bash
kubectl get pods -A -o wide
```

There should now be:

```text
Flannel on control plane
Flannel on worker
kube-proxy on control plane
kube-proxy on worker
CoreDNS running
```

---

# 10. Clean Up Bootstrap Credential

After the worker successfully joins, remove the temporary JoinConfiguration.

Local machine:

```bash
rm -f /tmp/kubeadm-join.yaml
```

Worker:

```bash
(
  cd configuration/ansible &&
  ansible k8s_workers \
    -u platform \
    -b \
    -m file \
    -a 'path=/tmp/kubeadm-join.yaml state=absent'
)
```

The bootstrap token may also be deleted after successful enrollment if it is no longer required.

List tokens:

```bash
sudo kubeadm token list
```

Delete the temporary token if desired:

```bash
sudo kubeadm token delete <TOKEN_ID>
```

---

# 11. Recreate GHCR Pull Credentials

The GHCR credential itself is intentionally not stored in Git.

The repository contains:

```text
scripts/create-ghcr-pull-secret.sh
```

From the local repository root, copy the script to the control plane:

```bash
scp scripts/create-ghcr-pull-secret.sh \
  platform@<CONTROL_PLANE_PUBLIC_IP>:/tmp/create-ghcr-pull-secret.sh
```

SSH into the control plane as `platform`, where `kubectl` is configured against the cluster:

```bash
ssh platform@<CONTROL_PLANE_PUBLIC_IP>
```

```bash
export GHCR_USERNAME=alirasheedmd
read -s GHCR_TOKEN
export GHCR_TOKEN
```

Run:

```bash
bash /tmp/create-ghcr-pull-secret.sh
```

The script should be safe to run repeatedly.

Verify:

```bash
kubectl get secret ghcr-pull
```

Expected:

```text
NAME        TYPE
ghcr-pull   kubernetes.io/dockerconfigjson
```

Remove the token from the shell environment:

```bash
unset GHCR_TOKEN
```

Never commit the token.

---

# 12. Restore Current Application Workload

Use the latest completed workload stage in Git.

At the Stage 2.9 checkpoint, this is:

```text
configuration/kubernetes/lab-web/deployment.yaml
```

The raw Pod and standalone ReplicaSet manifests remain in Git for earlier learning exercises. Apply only `deployment.yaml` during this rebuild; do not apply the entire `lab-web` directory. All three manifests use `app=lab-web`, so applying them together introduces overlapping workload selectors. See the [Kubernetes Deployment selector guidance](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#selector).

## 12.1 Check for earlier exercise workloads

On the control plane:

```bash
kubectl get deployment,rs,pods -n default -o wide
```

A fresh cluster should have no `lab-web` workload yet. If reusing a cluster from an earlier exercise, inspect the named standalone resources:

```bash
kubectl get rs lab-web -n default --ignore-not-found -o yaml
kubectl get pod lab-web -n default --ignore-not-found -o yaml
```

If these are the old exercise resources without a controller owner reference, remove them before applying the Deployment. This deletes the old exercise Pods and interrupts that workload:

```bash
kubectl delete rs lab-web -n default --ignore-not-found --cascade=foreground --wait=true
kubectl delete pod lab-web -n default --ignore-not-found --wait=true
```

Skip this cleanup on a fresh cluster. If either resource already has a controller owner reference, stop and inspect its ownership before deleting it. Do not delete ReplicaSets generated by an existing Deployment or delete all Pods by label.

## 12.2 Apply the Deployment

On the local machine, from the repository root, copy the manifest:

```bash
scp \
  configuration/kubernetes/lab-web/deployment.yaml \
  platform@<CONTROL_PLANE_PUBLIC_IP>:/tmp/lab-web-deployment.yaml
```

On the control plane:

```bash
kubectl apply -n default -f /tmp/lab-web-deployment.yaml
kubectl rollout status deployment/lab-web -n default --timeout=180s
```

Stop if the rollout fails or times out. Inspect `kubectl describe deployment lab-web -n default`, the affected Pods, and namespace events before continuing.

## 12.3 Verify replicas and controller ownership

```bash
kubectl get deployment lab-web -n default
kubectl get rs -n default -l app=lab-web
```

Expected:

```text
NAME      READY   UP-TO-DATE   AVAILABLE
lab-web   3/3     3            3
```

The active ReplicaSet normally has a generated name such as `lab-web-<pod-template-hash>` with `DESIRED`, `CURRENT`, and `READY` all equal to `3`. Older Deployment-owned ReplicaSets may remain at zero replicas after previous rollouts.

Verify the ownership chain:

```bash
kubectl get rs -n default -l app=lab-web \
  -o custom-columns='NAME:.metadata.name,OWNER_KIND:.metadata.ownerReferences[0].kind,OWNER_NAME:.metadata.ownerReferences[0].name,CONTROLLER:.metadata.ownerReferences[0].controller,DESIRED:.spec.replicas,READY:.status.readyReplicas'
kubectl get pods -n default -l app=lab-web \
  -o custom-columns='NAME:.metadata.name,OWNER_KIND:.metadata.ownerReferences[0].kind,OWNER_NAME:.metadata.ownerReferences[0].name,CONTROLLER:.metadata.ownerReferences[0].controller'
kubectl get pods -n default -l app=lab-web -o wide
```

Expected ownership:

```text
Deployment lab-web
    → ReplicaSet lab-web-<pod-template-hash> (controller owner: Deployment/lab-web)
        → 3 Pods (controller owner: that ReplicaSet)
```

The controller references should show `CONTROLLER=true`. After rollout completion and termination of old Pods, expect exactly three Running Pods, each `1/1` Ready. The Pods should normally be scheduled on:

```text
platform-k8s-worker-01
```

This proves workload convergence and ownership. The manifest has no readiness probe, and the Services stage is still pending, so it does not establish HTTP application health or external access.

---

# 13. Full Validation

Run:

```bash
kubectl get nodes -o wide
```

Both nodes must be:

```text
Ready
```

Run:

```bash
kubectl get pods -A -o wide
```

System Pods should be healthy.

Run:

```bash
kubectl get daemonset -n kube-flannel
```

Expected:

```text
2 / 2 / 2
```

Run:

```bash
kubectl get secret ghcr-pull
```

Expected registry Secret present.

Run:

```bash
kubectl rollout status deployment/lab-web -n default --timeout=180s
kubectl get deployment lab-web -n default
kubectl get rs -n default -l app=lab-web
```

Expected:

```text
Deployment lab-web: READY 3/3, UP-TO-DATE 3, AVAILABLE 3
Active Deployment-owned ReplicaSet: DESIRED 3, CURRENT 3, READY 3
```

Run:

```bash
kubectl get pods -n default -l app=lab-web -o wide
```

Expected:

```text
3 Running Pods, each 1/1 Ready
```

Repeat the owner-reference checks from Section 12.3. All application Pods must belong to a ReplicaSet controlled by `Deployment/lab-web`; a matching label alone is not ownership proof.

---

# 14. Expected Final Architecture

```text
Developer Mac
     │
     │ Terraform / Ansible / SSH
     ▼
DigitalOcean VPC
10.20.0.0/24
     │
     ├──────────────────────────────────────┐
     │                                      │
     ▼                                      ▼
platform-k8s-cp-01                  platform-k8s-worker-01
10.20.0.3                           10.20.0.2
     │                                      │
Control Plane                       kubelet
API Server                          containerd
etcd                                kube-proxy
Scheduler                           Flannel
Controller Manager                  lab-web Pods
kubelet
containerd
Flannel
     │                                      │
     └────────── Flannel VXLAN ─────────────┘
                  UDP 8472

Pod network:
10.244.0.0/16

Control-plane Pod subnet:
10.244.0.0/24

Worker Pod subnet:
10.244.1.0/24

Service network:
10.96.0.0/12

Application controller hierarchy:
Deployment lab-web → ReplicaSet lab-web-<pod-template-hash> → 3 Pods
```

---

# 15. Failure Rule During Rebuild

If something fails during a clean rebuild:

Do not immediately repair it manually.

First determine which layer failed:

```text
Terraform
    ↓
SSH/bootstrap
    ↓
Ansible prerequisites
    ↓
kubeadm control plane
    ↓
CNI
    ↓
worker join
    ↓
registry credentials
    ↓
application workload
```

Then:

1. identify the missing dependency;
2. fix the appropriate Terraform, Ansible, script, manifest, or documentation;
3. rerun the affected step;
4. record the lesson;
5. commit the fix.

A successful rebuild that depends on remembered manual commands is not considered reproducible.

---

# 16. Current Manual Gaps

The following are intentionally still manual at the current stage:

### Worker join

Currently:

```text
generate token
→ create JoinConfiguration
→ validate
→ join
```

This will be automated later.

### GHCR credential input

The secret creation process is scripted, but the actual token remains external by design.

### Workload application

Kubernetes manifests are stored in Git, but workload deployment is still manually invoked with `kubectl apply`.

These are acceptable current-state gaps because the later cluster-bootstrap automation stage will orchestrate them.

---

# 17. Fast Rebuild Checklist

Use this once the full procedure is familiar:

```text
[ ] git pull
[ ] terraform init
[ ] terraform plan
[ ] terraform apply
[ ] ./scripts/bootstrap-k8s.sh
[ ] run k8s-prerequisites.yml
[ ] rerun prerequisites for idempotency
[ ] run k8s-control-plane.yml
[ ] verify kubectl works as platform
[ ] install Flannel
[ ] verify control plane Ready
[ ] generate worker join token
[ ] create temporary JoinConfiguration
[ ] validate JoinConfiguration
[ ] join worker
[ ] verify both nodes Ready
[ ] verify Flannel 2/2
[ ] remove temporary join credential
[ ] create/update ghcr-pull Secret
[ ] check for and remove unowned earlier exercise workloads if present
[ ] apply lab-web deployment.yaml only (default namespace)
[ ] wait for Deployment rollout completion
[ ] verify Deployment 3/3 and active ReplicaSet 3/3/3
[ ] verify Deployment → ReplicaSet → Pod controller ownership
[ ] verify exactly three application Pods, each Running and 1/1 Ready
[ ] record any undocumented repair
```

---

# Rebuild Success Criteria

The lab is considered restored when:

```text
Infrastructure provisioned from Terraform        ✅
Nodes configured through Ansible                 ✅
Control plane bootstrapped                       ✅
kubectl usable without manual kubeconfig repair  ✅
Flannel operational                              ✅
Worker joined                                    ✅
Both nodes Ready                                 ✅
GHCR pull secret reproducible                    ✅
Application workload restored from Git           ✅
Deployment and active ReplicaSet converged        ✅
Deployment → ReplicaSet → Pod ownership verified ✅
No undocumented repair required                  ✅
```

The repository, not memory, should contain the knowledge required to rebuild the environment.
