# Clean-Room Platform Rebuild Runbook

## Purpose

This runbook describes how to reconstruct the Platform Engineering Lab after the compute layer has been destroyed.

The rebuild is considered successful only when all of the following are true:

- Terraform converges with no infrastructure drift.
- Fresh nodes are bootstrapped without manual server repair.
- Docker Swarm is reconstructed with the expected manager and worker.
- WireGuard deployment connectivity is restored.
- HTTPS ingress is reconstructed.
- GitHub Actions state referencing the rebuilt manager is refreshed.
- GitHub Actions can connect to the platform over WireGuard and SSH.
- A new application release can be built, pushed to GHCR, and deployed automatically.
- The deployed application is pinned to an immutable image digest.
- Public HTTP and HTTPS work through both Swarm nodes.
- Re-running the bootstrap produces no unintended changes.
- Re-running configuration does not replace the application release owned by CI/CD.

---

# Platform Ownership Model

The platform intentionally separates infrastructure, configuration, runtime, and release responsibilities.

```text
Terraform
    ↓
Cloud infrastructure

Ansible
    ↓
Host and platform configuration

Docker Swarm
    ↓
Runtime desired state and reconciliation

GitHub Actions
    ↓
Application build and release

GHCR
    ↓
Immutable application artifacts
```

Ownership boundaries:

| Layer                             | Owner                 |
| --------------------------------- | --------------------- |
| DigitalOcean Droplets             | Terraform             |
| DigitalOcean Firewall             | Terraform             |
| Existing VPC lookup               | Terraform data source |
| Existing cloud SSH key lookup     | Terraform data source |
| Linux baseline                    | Ansible               |
| Platform user                     | Ansible               |
| SSH hardening                     | Ansible               |
| Docker Engine                     | Ansible               |
| WireGuard server                  | Ansible               |
| Docker Swarm                      | Ansible               |
| Overlay network                   | Ansible / Swarm       |
| HTTPS ingress                     | Ansible / Swarm       |
| TLS material                      | Ansible               |
| Initial `lab-web` bootstrap state | Ansible               |
| Application build                 | GitHub Actions        |
| Application image                 | GHCR                  |
| Application release               | GitHub Actions        |
| Replica reconciliation            | Docker Swarm          |

A configuration run must not replace an application release already deployed by CI/CD.

---

# Important Rebuild Principle

Destroying infrastructure can invalidate state held outside Terraform and Ansible.

A successful `terraform apply` and successful Ansible run do **not** by themselves prove that the platform is ready for deployment.

After infrastructure recreation, identify external systems that reference resource identity.

For this lab, the following values change when the Swarm manager is recreated:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

These values must be synchronized with GitHub before testing CI/CD.

A rebuild is not complete until external consumers of recreated infrastructure have also been reconciled and validated.

---

# External State and Preconditions

The following state exists outside the disposable compute layer and must be available before rebuilding.

## DigitalOcean

Required:

- DigitalOcean API credentials
- Existing VPC
- Existing cloud SSH key
- Required API permissions

The current Terraform configuration looks up the VPC and SSH key rather than creating them.

These are therefore rebuild prerequisites.

---

## Local Administrative SSH Key

The SSH key referenced by DigitalOcean must be available locally.

Verify:

```bash
ssh-add -l
```

If required, load it:

```bash
ssh-add ~/.ssh/<administrative-key>
```

Fresh nodes initially require the administrative key because the `platform` user and deployment key have not yet been installed.

---

## Ansible Vault

The bootstrap uses Ansible Vault protected values.

The Vault password must be available when prompted.

```text
Vault password:
```

Do not commit Vault passwords or decrypted secret material.

---

## GitHub Repository Secrets

The deployment workflows currently reference:

```text
DEPLOY_SSH_PRIVATE_KEY
GHCR_READ_TOKEN
GITHUB_TOKEN
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
WG_PRIVATE_KEY
WG_SERVER_PUBLIC_KEY
```

`GITHUB_TOKEN` is created automatically by GitHub Actions and must not be manually provisioned.

Persistent repository secrets:

```text
DEPLOY_SSH_PRIVATE_KEY
GHCR_READ_TOKEN
WG_PRIVATE_KEY
WG_SERVER_PUBLIC_KEY
```

Rebuild-sensitive repository secrets:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

The rebuild-sensitive values must be refreshed after recreating the manager.

---

# Expected Final Platform

The reconstructed environment should contain:

```text
DigitalOcean VPC
│
├── platform-node-01
│   ├── Ubuntu 24.04
│   ├── Swarm Manager
│   ├── WireGuard endpoint
│   └── Ingress replica
│
└── platform-node-02
    ├── Ubuntu 24.04
    ├── Swarm Worker
    └── Ingress replica
```

Expected Swarm state:

```text
platform-node-01   Ready   Active   Leader
platform-node-02   Ready   Active
```

Expected services:

```text
lab-web       4/4
lab-ingress   2/2
```

Expected ingress behavior:

```text
HTTP  → 301 redirect to HTTPS
HTTPS → 200 OK
```

---

# Phase 1: Confirm Repository State

From the repository root:

```bash
git status
git log --oneline -5
```

Expected:

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

Do not begin a destructive or rebuild operation with unexplained local changes.

---

# Phase 2: Verify Terraform Starting State

Change into the Terraform directory:

```bash
cd infrastructure/terraform
```

Inspect the current state:

```bash
terraform state list
```

After a complete compute-layer destroy, no managed Droplet or firewall resources should remain.

Generate a plan:

```bash
terraform plan
```

For the current lab, a clean rebuild should plan approximately:

```text
3 to add, 0 to change, 0 to destroy
```

The created resources are:

```text
digitalocean_droplet.platform_node_01
digitalocean_droplet.platform_node_02
digitalocean_firewall.platform
```

The following are existing external dependencies and appear as data sources:

```text
data.digitalocean_regions.available
data.digitalocean_ssh_key.platform
data.digitalocean_vpc.platform
```

---

# Phase 3: Provision Infrastructure

Apply:

```bash
terraform apply
```

Review the plan before approving.

After completion:

```bash
terraform state list
terraform output
terraform plan
```

The final plan must report:

```text
No changes. Your infrastructure matches the configuration.
```

This is the Terraform convergence checkpoint.

## Stop Condition

Do not proceed if:

- Terraform reports unexpected changes.
- Required resources failed to create.
- Public or private addresses are missing.
- The final `terraform plan` still contains unexplained drift.

---

# Phase 4: Bootstrap Fresh Nodes

Return to the repository root:

```bash
cd ../..
```

Run:

```bash
./scripts/bootstrap-lab.sh
```

The bootstrap performs the following sequence:

```text
Terraform outputs
    ↓
Generate Ansible inventory
    ↓
Detect fresh or existing nodes
    ↓
Fresh root bootstrap if required
    ↓
Create platform user
    ↓
Install administrative SSH key
    ↓
Configure sudo
    ↓
SSH hardening
    ↓
Install Docker
    ↓
Authorize CI deployment SSH key
    ↓
Configure WireGuard
    ↓
Initialize Swarm manager
    ↓
Join worker
    ↓
Create overlay network
    ↓
Create or preserve lab-web
    ↓
Generate/adopt TLS
    ↓
Create immutable Docker configs/secrets
    ↓
Deploy ingress
    ↓
Verify reconstructed platform
```

On fresh nodes, the script should report:

```text
Fresh nodes detected; bootstrapping as root
```

No host should report:

```text
unreachable > 0
failed > 0
```

---

# Phase 5: Verify Bootstrap Result

The bootstrap contains an automated verification step.

A healthy reconstructed lab should produce a result similar to:

```text
PASS:
platform-node-01,platform-node-02;
private lab-web 4/4;
lab-ingress 2/2;
HTTP redirect and trusted HTTPS on both VPC addresses
```

Verify cluster membership:

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker node ls"
```

Expected:

```text
platform-node-01   Ready   Active   Leader
platform-node-02   Ready   Active
```

Verify services:

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service ls"
```

Expected bootstrap state:

```text
lab-web       4/4
lab-ingress   2/2
```

On a fresh platform, `lab-web` may initially use the pinned bootstrap image.

The application release is subsequently owned by GitHub Actions.

---

# Phase 6: Reconcile External GitHub State

The new manager receives a new public IP and SSH host identity.

Synchronize GitHub:

```bash
./scripts/sync-github-secrets.sh
```

Then inspect repository secret metadata:

```bash
gh secret list
```

The following should show recent updates:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

Persistent credentials do not need to change simply because compute was recreated.

---

# Phase 7: Audit Workflow Secret Dependencies

Before triggering CI/CD, verify that every repository secret referenced by the workflows is accounted for.

Run:

```bash
rg -o 'secrets\.[A-Z0-9_]+' .github/workflows | sort -u
```

Current expected references:

```text
secrets.DEPLOY_SSH_PRIVATE_KEY
secrets.GHCR_READ_TOKEN
secrets.GITHUB_TOKEN
secrets.PLATFORM_MANAGER_PUBLIC_IP
secrets.PLATFORM_SSH_KNOWN_HOST
secrets.WG_PRIVATE_KEY
secrets.WG_SERVER_PUBLIC_KEY
```

Do not manually create `GITHUB_TOKEN`.

It is supplied automatically by GitHub Actions.

## Stop Condition

Do not trigger an application deployment if a required external secret is missing or stale.

---

# Phase 8: Validate CI Connectivity Separately

Before testing the full application deployment path, test only the deployment connectivity layer.

Trigger:

```bash
gh workflow run platform-connectivity.yml
```

Find the run:

```bash
gh run list --workflow=platform-connectivity.yml --limit 3
```

Watch it:

```bash
gh run watch <RUN_ID>
```

The workflow should successfully complete:

```text
Install WireGuard
Configure WireGuard
Show WireGuard state
Test VPN reachability
Configure deployment SSH key
Test SSH over WireGuard
Verify Docker permissions
Authenticate Swarm manager to GHCR
```

This proves:

```text
GitHub Actions
    ↓
WireGuard
    ↓
private deployment path
    ↓
SSH
    ↓
platform user
    ↓
Docker / Swarm
    ↓
GHCR authentication
```

## Stop Condition

Do not proceed to application deployment if the connectivity workflow fails.

Fix the connectivity layer first.

---

# Phase 9: Establish Public Ingress Baseline

Test both public node addresses.

```bash
curl -I http://<NODE_01_PUBLIC_IP>
curl -kI https://<NODE_01_PUBLIC_IP>

curl -I http://<NODE_02_PUBLIC_IP>
curl -kI https://<NODE_02_PUBLIC_IP>
```

Expected HTTP result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://...
```

Expected HTTPS result:

```text
HTTP/1.1 200 OK
```

`-k` is used here only because the current lab uses a self-signed certificate for external test access.

Internal Ansible verification validates certificate trust explicitly and does not depend on `curl -k`.

---

# Phase 10: Trigger an Application Release

Make a deliberate visible change under:

```text
applications/lab-web/
```

Review it:

```bash
git diff
```

Commit:

```bash
git add applications/lab-web/
git commit -m "feat(lab-web): verify clean-room CI deployment"
```

Push:

```bash
git push origin main
```

Locate the workflow:

```bash
gh run list --workflow=lab-web-ci.yml --limit 3
```

Watch:

```bash
gh run watch <RUN_ID>
```

The workflow should complete:

```text
Checkout repository
Validate application files
Set up Docker Buildx
Log in to GHCR
Build application image
Show image digest
Install WireGuard
Configure WireGuard
Configure deployment SSH
Authenticate Swarm manager to GHCR
Deploy immutable image to Swarm
Verify Swarm rollout
```

---

# Phase 11: Verify Immutable Deployment

Inspect the deployed service image:

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service inspect lab-web --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'"
```

Expected form:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-<GIT_COMMIT>@sha256:<IMAGE_DIGEST>
```

Both the Git commit SHA tag and immutable digest should be present.

Example structure:

```text
ghcr.io/alirasheedmd/platform-lab-web:
sha-e18431842fa466381601851d4deb4380a01f8685
@sha256:a1d870...
```

The digest is the strongest artifact-identity proof.

---

# Phase 12: Verify Swarm Convergence

Run:

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service ls"
```

Expected:

```text
lab-ingress   replicated   2/2
lab-web       replicated   4/4
```

Do not treat a successful CI workflow alone as proof of successful deployment.

The runtime must also converge.

---

# Phase 13: Verify User-Visible Deployment

Fetch the application through both public node addresses:

```bash
curl -ks https://<NODE_01_PUBLIC_IP>
curl -ks https://<NODE_02_PUBLIC_IP>
```

Both responses must show the newly deployed application content.

This validates three independent layers:

```text
Desired state
    → Swarm reports expected replicas

Artifact identity
    → service references expected SHA + digest

User-visible state
    → both public ingress paths serve the new release
```

A release is not considered validated until all three agree.

---

# Phase 14: Prove Operational Idempotency

After the CI-owned release is live, rerun:

```bash
./scripts/bootstrap-lab.sh
```

On existing hosts the script should report:

```text
Platform user is available; skipping root bootstrap
```

Important tasks should remain unchanged:

```text
WireGuard configuration          ok
Swarm manager initialization     skipped
Worker join                      skipped
Overlay network creation         skipped
lab-web convergence              ok
TLS regeneration                 skipped unless renewal required
Ingress convergence              ok
```

Expected recap:

```text
changed=0
failed=0
unreachable=0
```

Certificate renewal may intentionally create changes when the renewal threshold is reached.

---

# Phase 15: Verify Release Preservation

After the bootstrap rerun, inspect the application image again:

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service inspect lab-web --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'"
```

It must still reference the exact CI-deployed GHCR SHA and digest.

It must **not** revert to the bootstrap image.

This proves the ownership boundary:

```text
Ansible
    owns platform configuration

GitHub Actions
    owns application release
```

Configuration management must not steal release ownership from CI/CD.

---

# Phase 16: Verify Repository Hygiene

The Ansible inventory is generated from Terraform outputs:

```text
configuration/ansible/inventory.ini
```

It is intentionally gitignored.

Verify:

```bash
git status
```

Expected:

```text
nothing to commit, working tree clean
```

Running the bootstrap must not dirty the repository simply because cloud IP addresses changed.

The repository tracks the inventory generator, not ephemeral generated infrastructure values.

---

# Final Acceptance Checklist

A clean-room rebuild is complete only when every item below passes.

```text
[ ] Repository started from a known clean state

[ ] Terraform created both nodes
[ ] Terraform created the firewall
[ ] Terraform final plan reports no changes

[ ] Fresh-node bootstrap completed
[ ] No Ansible failures
[ ] No unreachable hosts

[ ] platform-node-01 is Swarm Leader
[ ] platform-node-02 is Ready / Active

[ ] lab-web is 4/4
[ ] lab-ingress is 2/2

[ ] WireGuard server is configured
[ ] Deployment SSH key is authorized

[ ] PLATFORM_MANAGER_PUBLIC_IP refreshed
[ ] PLATFORM_SSH_KNOWN_HOST refreshed

[ ] Workflow secret dependency audit completed

[ ] Platform connectivity workflow passed
[ ] WireGuard connectivity passed
[ ] SSH-over-WireGuard passed
[ ] Docker permissions passed
[ ] GHCR authentication passed

[ ] HTTP redirects to HTTPS on node 01
[ ] HTTPS returns 200 on node 01
[ ] HTTP redirects to HTTPS on node 02
[ ] HTTPS returns 200 on node 02

[ ] Application CI workflow passed

[ ] lab-web image contains Git SHA tag
[ ] lab-web image is pinned by digest

[ ] Swarm rollout converged

[ ] New application content is visible through node 01
[ ] New application content is visible through node 02

[ ] Second bootstrap reports changed=0
[ ] Second bootstrap reports failed=0
[ ] CI-owned application digest is preserved

[ ] Generated inventory remains untracked
[ ] Git working tree remains clean
```

---

# Failure Handling Rules

## Do Not Manually Repair First

During a clean-room rebuild, do not immediately SSH into a host and manually modify configuration when automation fails.

Capture the failure first.

The purpose of the exercise is to identify missing automation.

A manual recovery step should become one of:

```text
Terraform configuration
Ansible role/task
bootstrap script logic
secret synchronization logic
CI/CD workflow logic
documented external prerequisite
```

Manual server state should not become an undocumented dependency.

---

## Stop at the Failing Layer

Do not continue through later stages after an earlier dependency has failed.

Examples:

```text
Terraform failure
    → do not bootstrap

Bootstrap failure
    → do not test CI

Secret reconciliation failure
    → do not deploy

Connectivity workflow failure
    → do not run application release

Release rollout failure
    → do not declare rebuild successful
```

This reduces the blast radius and keeps failure diagnosis isolated.

---

# Dependency Closure Check

Before advancing from one phase to the next, ask:

```text
What changed identity?

What external system references that identity?

What state survived destruction?

What state became stale?

What credentials are coupled to the recreated resource?

What downstream system depends on this layer?

What evidence proves the layer is actually healthy?
```

A successful command is not sufficient evidence that dependent systems are healthy.

---

# Proven Rebuild Properties

The clean-room rebuild performed on September 18, 2026 demonstrated:

- Destruction and reconstruction of the compute layer.
- Terraform convergence after provisioning.
- Fresh-node Ansible bootstrap.
- Automatic Linux baseline configuration.
- SSH hardening.
- Docker installation.
- Deployment SSH authorization.
- WireGuard reconstruction.
- Swarm manager initialization.
- Worker join.
- Overlay network recreation.
- HTTPS ingress reconstruction.
- TLS regeneration.
- `lab-web` convergence to four replicas.
- `lab-ingress` convergence to two replicas.
- Dynamic GitHub secret reconciliation.
- Successful GitHub Actions connectivity through WireGuard.
- Successful SSH deployment through the private deployment network.
- GHCR authentication from the deployment workflow.
- Immutable application build and deployment using Git SHA plus digest.
- Public HTTP-to-HTTPS behavior through both nodes.
- Successful HTTPS application access through both nodes.
- Bootstrap rerun with zero configuration changes.
- Preservation of the existing CI-owned application release.
- Clean handling of generated Ansible inventory outside Git tracking.

---

# Operational Definition of Reproducibility

For this lab, reproducibility means more than being able to create two virtual machines.

The platform is considered reproducible when:

```text
source-controlled infrastructure
        +
source-controlled configuration
        +
controlled external credentials
        +
documented external dependencies
        +
repeatable reconciliation
        +
automated validation
        =
working platform after destruction
```

The target is not "the commands worked once."

The target is:

> The platform can be destroyed, reconstructed, validated, released to, and safely reconciled again without relying on undocumented manual server state.
