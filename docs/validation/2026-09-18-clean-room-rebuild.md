# Clean-Room Rebuild Validation

**Date:** September 18, 2026  
**Scope:** Full compute-layer reconstruction, platform bootstrap, external CI-state reconciliation, connectivity validation, immutable application deployment, public verification and idempotency.

---

## Objective

Validate that the Platform Engineering Lab can be reconstructed after destruction of the disposable compute layer without undocumented manual server repair.

The test also verifies that:

- external systems referencing recreated infrastructure can be reconciled,
- GitHub Actions can reconnect to the rebuilt platform,
- CI/CD can deploy a new immutable release,
- the platform remains idempotent after reconstruction,
- Ansible does not overwrite the CI-owned application release.

---

# Starting Repository State

Repository:

```text
branch: main
working tree: clean
remote: origin/main
```

Relevant commits before reconstruction:

```text
1d079b3 fix(platform): make bootstrap Ansible Vault aware
302cec5 feat(platform): automate deployment access recovery
a393cd9 feat(lab-web): update release page for HTTPS ingress
a2a116a feat(platform): add reproducible HTTPS ingress and lab verification
4c5cc4a Deploy lab web to Swarm through private CI network
```

---

# Phase 1: Terraform Reconstruction

Initial plan:

```text
Plan: 3 to add, 0 to change, 0 to destroy.
```

Resources recreated:

```text
digitalocean_droplet.platform_node_01
digitalocean_droplet.platform_node_02
digitalocean_firewall.platform
```

External Terraform dependencies:

```text
data.digitalocean_regions.available
data.digitalocean_ssh_key.platform
data.digitalocean_vpc.platform
```

Post-apply infrastructure:

```text
platform-node-01
public:  134.209.153.119
private: 10.10.10.3

platform-node-02
public:  157.245.102.86
private: 10.10.10.2

VPC:
2a1801a5-4bfa-4abe-a7d8-84dcfa0ace47
```

Final Terraform verification:

```text
No changes. Your infrastructure matches the configuration.
```

### Result

```text
Terraform reconstruction: PASS
Terraform convergence:    PASS
```

---

# Phase 2: Fresh-Node Bootstrap

Command:

```bash
./scripts/bootstrap-lab.sh
```

The bootstrap correctly detected fresh infrastructure:

```text
Fresh nodes detected; bootstrapping as root
```

Initial host configuration completed successfully on both nodes.

Fresh bootstrap recap:

```text
platform-node-01 : ok=15 changed=11 unreachable=0 failed=0
platform-node-02 : ok=15 changed=11 unreachable=0 failed=0
```

The bootstrap configured:

- baseline Linux packages,
- timezone,
- `/opt/platform`,
- `platform` administrative user,
- administrative SSH key,
- passwordless sudo,
- SSH hardening,
- Docker repository,
- Docker Engine,
- Docker CLI and runtime components.

No manual host repair was required.

---

# Phase 3: Deployment Access and WireGuard

The same bootstrap run then configured the deployment control path.

Validated operations:

```text
Authorize GitHub Actions deployment SSH key    PASS
Install WireGuard tools                        PASS
Create WireGuard configuration directory       PASS
Install WireGuard private key                  PASS
Install WireGuard configuration                PASS
Enable and start WireGuard                     PASS
```

The deployment SSH public key was installed automatically on the manager.

### Result

```text
Deployment SSH authorization: PASS
WireGuard reconstruction:      PASS
```

---

# Phase 4: Swarm Reconstruction

The manager was initialized automatically:

```text
platform-node-01 → Swarm Manager
```

The worker join token was retrieved and:

```text
platform-node-02 → joined as Worker
```

Final node state:

```text
platform-node-01   Ready   Active   Leader
platform-node-02   Ready   Active
```

Docker Engine version:

```text
29.8.1
```

### Result

```text
Swarm manager reconstruction: PASS
Worker membership:            PASS
```

---

# Phase 5: Overlay and Application Bootstrap

The bootstrap:

- checked for `platform-overlay`,
- created it when absent,
- inspected existing application release state,
- created the initial private `lab-web` service without assuming ownership of future CI releases.

Fresh bootstrap application target:

```text
lab-web 4/4
```

### Result

```text
Overlay reconstruction: PASS
Private application:    PASS
```

---

# Phase 6: TLS and HTTPS Ingress Reconstruction

The rebuild created the complete ingress path.

Validated operations included:

- protected ingress material directory,
- TLS private-key generation,
- certificate request generation,
- self-signed certificate creation,
- Nginx configuration creation,
- certificate/key validation,
- content-derived Docker object naming,
- Docker Config creation,
- Docker Secret creation,
- `lab-ingress` service convergence.

Final ingress target:

```text
lab-ingress 2/2
```

Internal platform verification reported:

```text
PASS:
platform-node-01,platform-node-02;
private lab-web 4/4;
lab-ingress 2/2;
HTTP redirect and trusted HTTPS on 10.10.10.3,10.10.10.2
```

### Result

```text
TLS reconstruction:     PASS
HTTPS ingress:          PASS
Internal verification: PASS
```

---

# Phase 7: External GitHub State Reconciliation

Recreating the manager changed:

- public IP address,
- SSH host identity.

The following GitHub repository secrets were refreshed using:

```bash
./scripts/sync-github-secrets.sh
```

Updated:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

Persistent secrets remained unchanged:

```text
DEPLOY_SSH_PRIVATE_KEY
GHCR_READ_TOKEN
WG_PRIVATE_KEY
WG_SERVER_PUBLIC_KEY
```

Workflow secret references were audited with:

```bash
rg -o 'secrets\.[A-Z0-9_]+' .github/workflows | sort -u
```

Observed dependency set:

```text
secrets.DEPLOY_SSH_PRIVATE_KEY
secrets.GHCR_READ_TOKEN
secrets.GITHUB_TOKEN
secrets.PLATFORM_MANAGER_PUBLIC_IP
secrets.PLATFORM_SSH_KNOWN_HOST
secrets.WG_PRIVATE_KEY
secrets.WG_SERVER_PUBLIC_KEY
```

`GITHUB_TOKEN` is supplied automatically by GitHub Actions.

### Result

```text
Dynamic GitHub state reconciliation: PASS
Workflow secret dependency audit:    PASS
```

---

# Phase 8: CI Connectivity Validation

Workflow:

```text
Platform Connectivity Test
```

Run ID:

```text
35318190341
```

Result:

```text
success
```

Validated workflow steps:

```text
Install WireGuard                         PASS
Configure WireGuard                       PASS
Show WireGuard state                      PASS
Test VPN reachability                     PASS
Configure deployment SSH key              PASS
Test SSH over WireGuard                   PASS
Verify Docker permissions                 PASS
Authenticate Swarm manager to GHCR        PASS
```

### Result

```text
GitHub Actions → WireGuard: PASS
WireGuard → manager:         PASS
SSH deployment path:         PASS
Docker access:               PASS
GHCR authentication:         PASS
```

---

# Phase 9: Public Ingress Baseline

Both public node addresses were tested before application deployment.

## Node 01

```text
http://134.209.153.119
→ HTTP/1.1 301 Moved Permanently

https://134.209.153.119
→ HTTP/1.1 200 OK
```

## Node 02

```text
http://157.245.102.86
→ HTTP/1.1 301 Moved Permanently

https://157.245.102.86
→ HTTP/1.1 200 OK
```

Both HTTPS responses returned the same bootstrap application state.

### Result

```text
Node 01 HTTP → HTTPS: PASS
Node 01 HTTPS:        PASS
Node 02 HTTP → HTTPS: PASS
Node 02 HTTPS:        PASS
```

---

# Phase 10: Immutable CI/CD Deployment

A visible application change was committed to validate the complete delivery path.

Release commit:

```text
e18431842fa466381601851d4deb4380a01f8685
```

GitHub Actions workflow:

```text
Lab Web CI
```

Run ID:

```text
35318776710
```

Result:

```text
success
```

Successful workflow stages:

```text
Checkout repository                  PASS
Validate application files           PASS
Set up Docker Buildx                 PASS
Log in to GHCR                       PASS
Build application image              PASS
Show image digest                    PASS
Install WireGuard                    PASS
Configure WireGuard                  PASS
Configure deployment SSH             PASS
Authenticate Swarm manager to GHCR   PASS
Deploy immutable image to Swarm      PASS
Verify Swarm rollout                 PASS
```

### Result

```text
CI build:        PASS
Registry push:   PASS
Private deploy:  PASS
Swarm rollout:   PASS
```

---

# Phase 11: Artifact Identity Verification

The deployed Swarm service was inspected directly.

Observed image:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-e18431842fa466381601851d4deb4380a01f8685@sha256:a1d870a474ef13f515253394c6e71ecc74db4d21f199b069d8d7875f1b50bfe7
```

This proves:

```text
Git commit:
e18431842fa466381601851d4deb4380a01f8685

OCI image digest:
sha256:a1d870a474ef13f515253394c6e71ecc74db4d21f199b069d8d7875f1b50bfe7
```

### Result

```text
Source traceability:          PASS
Immutable artifact identity:  PASS
```

---

# Phase 12: Runtime Convergence

Final service state:

```text
lab-ingress   replicated   2/2
lab-web       replicated   4/4
```

`lab-web` was running the GHCR release:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-e18431842fa466381601851d4deb4380a01f8685
```

### Result

```text
lab-web convergence:     PASS
lab-ingress convergence: PASS
```

---

# Phase 13: User-Visible Release Verification

Both public ingress paths served the new application release.

Observed content:

```html
<h1>Platform Engineering Lab</h1>
<p>Version: v1.3.0</p>

<h1>Clean-Room Rebuild Deployment</h1>
<p>September 18, 2026</p>
```

Validated through:

```text
134.209.153.119
157.245.102.86
```

### Result

```text
Node 01 new release: PASS
Node 02 new release: PASS
```

This verified agreement across:

```text
CI workflow
    ↓
GHCR artifact
    ↓
Swarm service specification
    ↓
running replicas
    ↓
ingress
    ↓
user-visible application
```

---

# Phase 14: Operational Idempotency

After the CI-owned release was live, the complete bootstrap was run again:

```bash
./scripts/bootstrap-lab.sh
```

The script correctly detected the existing platform:

```text
Platform user is available; skipping root bootstrap
```

Observed behavior:

```text
Deployment SSH authorization     ok
WireGuard installation           ok
WireGuard configuration          ok
Swarm initialization             skipped
Worker join                      skipped
Overlay creation                 skipped
lab-web reconciliation           ok
TLS regeneration                 skipped
Ingress reconciliation           ok
```

Final Ansible recap:

```text
platform-node-01 : ok=34 changed=0 unreachable=0 failed=0 skipped=4
platform-node-02 : ok=2  changed=0 unreachable=0 failed=0 skipped=1
```

### Result

```text
Operational idempotency: PASS
```

---

# Phase 15: Release Ownership Preservation

After the Ansible rerun, the application image remained:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-e18431842fa466381601851d4deb4380a01f8685@sha256:a1d870a474ef13f515253394c6e71ecc74db4d21f199b069d8d7875f1b50bfe7
```

It did not revert to the Ansible bootstrap image.

This validated the ownership boundary:

```text
Ansible
    → platform configuration

GitHub Actions
    → application release
```

### Result

```text
CI release preservation: PASS
```

---

# Phase 16: Generated Inventory Hygiene

The rebuild changed public node addresses.

The generated Ansible inventory therefore changed from the previous infrastructure addresses.

The inventory was identified as runtime-generated state:

```text
configuration/ansible/inventory.ini
```

It is now:

- generated from Terraform outputs,
- available locally,
- consumed by Ansible,
- excluded from Git tracking.

The README records it as:

```text
inventory.ini  # generated from Terraform outputs, gitignored
```

Final repository state:

```text
On branch main
Your branch is up to date with 'origin/main'.

nothing to commit, working tree clean
```

### Result

```text
Generated-state handling: PASS
Repository cleanliness:    PASS
```

---

# Final Validation Matrix

| Capability | Result |
|---|---|
| Terraform reconstruction | PASS |
| Terraform convergence | PASS |
| Fresh-node bootstrap | PASS |
| Linux baseline | PASS |
| SSH hardening | PASS |
| Docker installation | PASS |
| Deployment SSH authorization | PASS |
| WireGuard reconstruction | PASS |
| Swarm manager reconstruction | PASS |
| Worker join | PASS |
| Overlay reconstruction | PASS |
| `lab-web` 4/4 | PASS |
| `lab-ingress` 2/2 | PASS |
| TLS reconstruction | PASS |
| HTTPS ingress | PASS |
| GitHub dynamic-state reconciliation | PASS |
| Workflow secret dependency audit | PASS |
| GitHub → WireGuard connectivity | PASS |
| SSH over WireGuard | PASS |
| Docker deployment permissions | PASS |
| GHCR authentication | PASS |
| Public HTTP redirect | PASS |
| Public HTTPS | PASS |
| CI image build | PASS |
| Immutable GHCR artifact | PASS |
| Swarm rolling deployment | PASS |
| SHA + digest verification | PASS |
| Public release verification | PASS |
| Bootstrap idempotency | PASS |
| CI release preservation | PASS |
| Generated inventory hygiene | PASS |
| Clean Git working tree | PASS |

---

# Findings

## 1. Rebuild success spans multiple state domains

Reconstructing the servers alone is not sufficient.

The manager's recreated identity invalidated GitHub-side references:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

These values had to be reconciled before CI/CD could safely proceed.

---

## 2. External dependency reconciliation is part of recovery

The complete recovery path is therefore:

```text
Infrastructure reconstruction
        ↓
Platform reconstruction
        ↓
External-state reconciliation
        ↓
Connectivity validation
        ↓
Application release
        ↓
User-visible validation
```

---

## 3. Configuration and release ownership must remain separate

Ansible successfully reconstructed the initial service but preserved the later CI-owned immutable image during its second run.

This prevents configuration management from fighting with the deployment system.

---

## 4. Idempotency is separate from reproducibility

Two independent properties were proven:

```text
Clean-room reproducibility
    → rebuild after destruction

Operational idempotency
    → safely reconcile an existing platform
```

Both are required for predictable platform operation.

---

## 5. Generated runtime values should not become source state

Tracking `inventory.ini` caused infrastructure recreation to dirty the repository solely because public IP addresses changed.

The inventory is now correctly treated as derived runtime state.

---

# Remaining Boundaries

This validation does not prove:

- highly available Swarm manager quorum,
- stateful disaster recovery,
- automated backup/restore,
- publicly trusted TLS,
- managed external load balancing,
- production-grade centralized secret management,
- complete metrics/logging observability,
- multi-region recovery.

The validated scope is a reproducible stateless application platform with automated infrastructure, configuration, ingress and CI/CD delivery.

---

# Conclusion

The September 18, 2026 clean-room exercise demonstrated that the disposable compute layer can be destroyed and reconstructed from repository-controlled automation without undocumented manual server repair.

The validation also proved that:

```text
Terraform
    reconstructs infrastructure

Ansible
    reconstructs and reconciles the platform

Docker Swarm
    maintains runtime desired state

GitHub Actions
    delivers immutable releases

WireGuard
    provides the private deployment path

External-state reconciliation
    restores cross-system dependencies

End-to-end validation
    proves the rebuilt platform actually works
```

The final result was a rebuilt two-node Swarm platform serving a newly built immutable application release through both HTTPS ingress paths, followed by a second configuration run with zero changes and no loss of the CI-owned release.
