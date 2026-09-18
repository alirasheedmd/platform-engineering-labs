# Lab Reproducibility

The operational target is a two-node Docker Swarm platform with:

- one Swarm manager,
- one Swarm worker,
- a private `lab-web` service with four replicas,
- two `lab-ingress` replicas,
- HTTP-to-HTTPS redirection,
- TLS termination at ingress,
- private service communication over `platform-overlay`,
- WireGuard-based CI deployment connectivity,
- immutable application releases from GHCR.

The purpose of reproducibility in this lab is not simply to recreate virtual machines.

The platform should be reconstructable from source-controlled infrastructure and configuration, reconciled with required external state, validated automatically, and capable of receiving a new application release without undocumented manual repair.

---

# Reproducibility Model

The platform separates infrastructure, configuration, runtime state, and application delivery.

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
Application release

GHCR
    ↓
Immutable application artifacts
```

This separation is intentional.

A tool should not silently take ownership of state belonging to another layer.

---

# Ownership and Prerequisites

## Terraform

Terraform owns the disposable cloud infrastructure used by the lab:

- DigitalOcean Droplets,
- DigitalOcean firewall configuration,
- infrastructure outputs,
- associations with required cloud dependencies.

The current configuration also reads existing cloud objects through data sources, including:

- the DigitalOcean VPC,
- the administrative SSH key.

These objects are external prerequisites rather than disposable resources owned by the current Terraform configuration.

---

## Ansible

Ansible owns platform configuration:

- Linux baseline packages,
- timezone,
- platform administrative user,
- SSH public-key provisioning,
- sudo configuration,
- SSH hardening,
- Docker installation,
- deployment SSH authorization,
- WireGuard server configuration,
- Docker Swarm initialization and worker membership,
- overlay networking,
- bootstrap application state,
- HTTPS ingress,
- TLS material,
- platform verification.

Ansible must preserve an existing application release deployed by CI/CD.

---

## Docker Swarm

Docker Swarm owns runtime desired state and reconciliation:

- node membership,
- service replica counts,
- service placement,
- rolling service updates,
- service rollback behavior,
- overlay networking,
- Docker Config and Secret attachment.

A healthy platform currently expects:

```text
platform-node-01   Ready   Active   Leader
platform-node-02   Ready   Active
```

and:

```text
lab-web       4/4
lab-ingress   2/2
```

---

## GitHub Actions

GitHub Actions owns application release delivery:

```text
source change
    ↓
build
    ↓
GHCR
    ↓
immutable SHA tag
    ↓
image digest
    ↓
WireGuard
    ↓
SSH
    ↓
Swarm service update
```

The resulting application image should be expressed in the form:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-<COMMIT>@sha256:<DIGEST>
```

This gives the release both:

- source traceability through the Git commit,
- artifact identity through the OCI digest.

---

# External State

Not all platform state is disposable.

The rebuild depends on controlled external state that survives destruction of the Droplets.

Examples include:

- DigitalOcean API credentials,
- existing DigitalOcean VPC,
- existing cloud SSH key,
- local administrative SSH key,
- Ansible Vault protected values,
- deployment SSH identity,
- WireGuard identities,
- GHCR credential,
- GitHub repository secrets.

These dependencies must be documented because reproducibility does not mean eliminating all external state.

It means making external state intentional, controlled, and recoverable.

---

# Rebuild-Sensitive External State

Some external state becomes stale when infrastructure identity changes.

A newly created Swarm manager receives a new public IP address and SSH host identity.

The following GitHub repository secrets therefore need to be refreshed after a rebuild:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

The current synchronization entry point is:

```bash
./scripts/sync-github-secrets.sh
```

Persistent credentials such as the deployment SSH private key, WireGuard client identity and GHCR credential do not need to rotate merely because the VM was recreated.

This distinction is important:

```text
Persistent identity
    ≠
Recreated infrastructure identity
```

A successful server rebuild is not sufficient if external systems still reference the destroyed server.

---

# Administrative Requirements

Install Ansible and the pinned collections:

```bash
ansible-galaxy collection install -r configuration/ansible/requirements.yml
```

Terraform credentials, state access, cloud inputs and administrative SSH access must already be available.

Fresh nodes require the administrative SSH key attached through DigitalOcean.

The deployment key cannot be relied upon during the earliest bootstrap stage because its public key has not yet been installed on the new manager.

---

# Generated Inventory

The Ansible inventory is generated dynamically from current Terraform outputs:

```text
configuration/ansible/inventory.ini
```

The generator is:

```text
scripts/generate-inventory.sh
```

The inventory contains ephemeral infrastructure data such as current public addresses and is intentionally excluded from Git tracking.

The repository tracks the generator and configuration logic, not the generated runtime values.

This prevents a clean infrastructure rebuild from creating unrelated Git working-tree changes merely because cloud IP addresses changed.

---

# Bootstrap Entry Point

The primary rebuild entry point is:

```bash
./scripts/bootstrap-lab.sh
```

The script:

1. generates the current Ansible inventory,
2. refreshes SSH host keys,
3. detects whether hosts are fresh or already bootstrapped,
4. performs root bootstrap only when required,
5. transitions to the `platform` administrative user,
6. configures deployment access,
7. configures WireGuard,
8. initializes or preserves Docker Swarm,
9. joins workers when necessary,
10. creates or preserves the overlay network,
11. creates the bootstrap application only when no release exists,
12. configures TLS and HTTPS ingress,
13. verifies the reconstructed platform.

A fresh environment reports:

```text
Fresh nodes detected; bootstrapping as root
```

An existing platform reports:

```text
Platform user is available; skipping root bootstrap
```

---

# Application Release Ownership

A fresh platform needs an initial application service so that the runtime and ingress layers can be reconstructed.

On fresh infrastructure, `lab-web` may initially use the pinned bootstrap image declared in Ansible configuration.

Once GitHub Actions deploys an application release, Ansible must preserve that release.

The intended ownership transition is:

```text
Fresh rebuild
    ↓
Ansible creates viable bootstrap service
    ↓
GitHub Actions deploys application artifact
    ↓
CI/CD owns release identity from this point forward
```

Re-running Ansible must not replace the current GHCR image with the bootstrap image.

This behavior was explicitly validated during the September 18 rebuild.

---

# TLS Lifecycle

The lab uses self-signed TLS for the current environment.

The TLS configuration declares:

- lab hostname,
- validity period,
- renewal window,
- manager-side material directory,
- ingress configuration.

On a fresh manager, Ansible generates the private key and certificate.

The private material is stored under the protected manager directory.

The directory uses restrictive permissions and the private key is not copied back to the controller.

Secret-bearing operations suppress Ansible output and diffs where appropriate.

---

# Docker Config and Secret Lifecycle

Public ingress material is represented using Docker Configs.

Private TLS key material is represented using a Docker Secret.

The ingress service consumes:

```text
Nginx configuration
    → Docker Config

Public certificate
    → Docker Config

Private TLS key
    → Docker Secret
```

Object names are versioned using content-derived identifiers.

If content has not changed, the existing Docker object is reused.

A certificate renewal results in new immutable Docker objects and an ingress update.

This avoids mutating Docker Configs or Secrets in place.

Old objects may remain available for rollback and should only be removed after confirming they are no longer referenced by current or previous service specifications.

---

# Ingress Validation

Before updating ingress, Nginx configuration and the certificate/key pair are validated using a temporary container on the manager.

The ingress update policy performs controlled replica replacement and requests rollback when rollout fails.

Platform verification checks both service state and HTTP behavior.

The current expected behavior is:

```text
HTTP
    ↓
301 redirect

HTTPS
    ↓
200 OK
```

through both Swarm nodes.

---

# Certificate Trust

Internal verification validates the self-signed certificate explicitly rather than disabling verification.

The Ansible verification path uses certificate-aware requests such as:

```text
curl --cacert
```

with the appropriate hostname resolution.

For simple external smoke testing against public IP addresses, `curl -k` may be used because the lab certificate is self-signed and its hostname is not the public IP.

These two validation modes serve different purposes:

```text
Internal verification
    → prove certificate and TLS configuration are correct

External smoke test
    → prove public firewall/routing/ingress reachability
```

A rebuild that generates a new certificate also generates a new trust identity.

External clients relying on explicit certificate trust must trust the newly generated certificate.

---

# Verify Without Reconfiguring the Platform

The platform can be verified independently of a configuration run.

From `configuration/ansible`:

```bash
ansible-playbook \
  -u platform \
  --private-key ~/.ssh/platform-lab-deploy \
  playbooks/verify.yml
```

The verification requires:

- expected nodes to be present,
- nodes to be Ready and Active,
- correct manager state,
- expected service replica counts,
- private application reachability,
- image consistency,
- current Docker Config and Secret attachment,
- HTTP-to-HTTPS redirect behavior,
- successful HTTPS responses.

To require a specific application release:

```bash
ansible-playbook \
  -u platform \
  --private-key ~/.ssh/platform-lab-deploy \
  playbooks/verify.yml \
  -e 'lab_expected_web_image=ghcr.io/alirasheedmd/platform-lab-web:sha-COMMIT@sha256:DIGEST'
```

Replace the example with the actual release tag and digest.

Internal verification does not prove public cloud firewall reachability.

Public ingress should therefore also be tested from an external client.

---

# CI Connectivity Validation

Application deployment is deliberately separated from infrastructure validation.

Before triggering the full application release workflow, run the dedicated connectivity workflow:

```bash
gh workflow run platform-connectivity.yml
```

Locate the run:

```bash
gh run list --workflow=platform-connectivity.yml --limit 3
```

Then:

```bash
gh run watch <RUN_ID>
```

The connectivity workflow validates:

- WireGuard installation on the runner,
- WireGuard configuration,
- VPN reachability,
- deployment SSH key setup,
- SSH over WireGuard,
- Docker access,
- Swarm manager access,
- GHCR authentication.

This provides a narrower failure domain than immediately testing the complete application build and deployment pipeline.

---

# Workflow Secret Dependency Audit

The repository's workflow secret references can be audited with:

```bash
rg -o 'secrets\.[A-Z0-9_]+' .github/workflows | sort -u
```

The currently expected set is:

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

The other required values are repository-managed secrets.

A deployment should not be triggered until the workflow dependency set has been reconciled with the available secrets.

---

# Application Deployment Validation

The application release workflow is:

```text
.github/workflows/lab-web-ci.yml
```

A successful release performs:

```text
Checkout
    ↓
Application validation
    ↓
Docker Buildx
    ↓
GHCR authentication
    ↓
Application image build
    ↓
Immutable digest capture
    ↓
WireGuard setup
    ↓
Deployment SSH setup
    ↓
Manager GHCR authentication
    ↓
Swarm service update
    ↓
Rollout verification
```

After the workflow succeeds, verify the deployed image directly:

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service inspect lab-web --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'"
```

The service should contain the Git SHA and image digest.

---

# Three-Layer Release Verification

A successful workflow alone is not sufficient proof of a valid application deployment.

The release should be verified at three independent layers.

## 1. Desired State

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service ls"
```

Expected:

```text
lab-web       4/4
lab-ingress   2/2
```

---

## 2. Artifact Identity

```bash
ssh platform@<MANAGER_PUBLIC_IP> \
  "sudo docker service inspect lab-web --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'"
```

Expected:

```text
ghcr.io/...:sha-<COMMIT>@sha256:<DIGEST>
```

---

## 3. User-Visible State

Fetch the application through both public nodes:

```bash
curl -ks https://<NODE_01_PUBLIC_IP>
curl -ks https://<NODE_02_PUBLIC_IP>
```

Both entry points should serve the expected application release.

Only when all three agree should the deployment be treated as verified.

---

# Idempotency

Reproducibility also requires safe repeated reconciliation.

After a successful release, rerun:

```bash
./scripts/bootstrap-lab.sh
```

With unchanged desired state, the expected Ansible recap is:

```text
changed=0
failed=0
unreachable=0
```

The following operations should also behave idempotently:

```text
Swarm initialization
    → skipped when already initialized

Worker join
    → skipped when already joined

Overlay network creation
    → skipped when already present

WireGuard configuration
    → unchanged

Deployment SSH authorization
    → unchanged

TLS generation
    → skipped unless renewal is required

Docker Config/Secret creation
    → reuse existing content versions

Ingress convergence
    → unchanged

Application convergence
    → preserve existing CI release
```

Certificate renewal is an intentional exception when the configured renewal threshold is reached.

---

# Operational Idempotency vs Rebuild Reproducibility

The lab distinguishes two different properties.

## Rebuild Reproducibility

```text
Can the platform be reconstructed after destruction?
```

This requires:

- infrastructure provisioning,
- fresh-node bootstrap,
- platform reconstruction,
- external state reconciliation,
- CI connectivity,
- application deployment,
- end-to-end validation.

---

## Operational Idempotency

```text
Can the same automation safely run again against the live platform?
```

This requires:

- no unnecessary infrastructure changes,
- no unnecessary host changes,
- no Swarm reinitialization,
- no unnecessary worker rejoin,
- no unnecessary TLS regeneration,
- no replacement of the current application release,
- no source-repository drift from generated runtime files.

Both properties were validated during the September 18, 2026 clean-room exercise.

---

# Proven Clean-Room Rebuild

On September 18, 2026, the compute layer was recreated and the platform was rebuilt from the repository.

The following properties were validated.

## Infrastructure

- Two DigitalOcean nodes were recreated through Terraform.
- The cloud firewall was recreated.
- Existing VPC and SSH key prerequisites were resolved through Terraform data sources.
- Terraform converged to:

```text
No changes. Your infrastructure matches the configuration.
```

---

## Fresh Host Bootstrap

The bootstrap detected fresh hosts and successfully:

- connected using the administrative key,
- created the `platform` user,
- installed the administrative SSH key,
- configured passwordless sudo,
- hardened SSH,
- installed Docker,
- configured the platform baseline.

No host was unreachable and no bootstrap task failed.

---

## Deployment Access

The rebuild automatically:

- authorized the GitHub Actions deployment SSH key,
- installed WireGuard,
- installed the WireGuard private key,
- installed WireGuard configuration,
- enabled and started WireGuard.

No manual server repair was required.

---

## Swarm Reconstruction

The rebuild:

- initialized `platform-node-01` as manager,
- obtained the worker join token,
- joined `platform-node-02`,
- created `platform-overlay`,
- reconstructed application and ingress services.

Final node state:

```text
platform-node-01   Ready   Active   Leader
platform-node-02   Ready   Active
```

---

## Ingress and TLS Reconstruction

The rebuild:

- created protected ingress material storage,
- generated TLS material on the fresh manager,
- generated the certificate request,
- created the self-signed certificate,
- validated Nginx and the certificate/key pair,
- created immutable Docker Config and Secret objects,
- converged `lab-ingress`.

Final service state:

```text
lab-web       4/4
lab-ingress   2/2
```

---

## External CI State Reconciliation

After infrastructure reconstruction:

```text
PLATFORM_MANAGER_PUBLIC_IP
PLATFORM_SSH_KNOWN_HOST
```

were refreshed in GitHub.

The workflow dependency set was audited before application deployment.

This closed the external dependency that exists outside Terraform and Ansible.

---

## Private Deployment Connectivity

The dedicated Platform Connectivity workflow passed all stages:

- WireGuard installation,
- WireGuard configuration,
- VPN reachability,
- deployment SSH configuration,
- SSH over WireGuard,
- Docker permission verification,
- GHCR authentication.

This proved that the rebuilt infrastructure was reachable from GitHub Actions through the intended private deployment path.

---

## Public Ingress

Both public node addresses were externally tested.

For each node:

```text
HTTP  → 301
HTTPS → 200
```

This proved that the cloud firewall, Swarm routing path, ingress service and application path were reachable externally.

---

## Immutable Application Release

A new application release was committed and pushed.

The `lab-web-ci.yml` workflow successfully:

- validated application files,
- built the application image,
- pushed to GHCR,
- captured the image digest,
- established WireGuard connectivity,
- authenticated to the Swarm manager,
- updated the service,
- verified rollout convergence.

The deployed application image was:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-e18431842fa466381601851d4deb4380a01f8685@sha256:a1d870a474ef13f515253394c6e71ecc74db4d21f199b069d8d7875f1b50bfe7
```

This demonstrated immutable deployment using both source SHA and OCI digest.

---

## User-Visible Release Verification

Both public node addresses returned the newly deployed application content.

This confirmed agreement between:

```text
GitHub Actions
    ↓
GHCR artifact
    ↓
Swarm service specification
    ↓
running replicas
    ↓
public ingress
    ↓
user-visible application
```

---

# Proven Idempotency

After the CI release was live, the complete bootstrap was run again.

The script detected the existing platform:

```text
Platform user is available; skipping root bootstrap
```

The Ansible recap reported:

```text
platform-node-01   changed=0   failed=0   unreachable=0
platform-node-02   changed=0   failed=0   unreachable=0
```

Swarm initialization was skipped.

Worker join was skipped.

Overlay creation was skipped.

TLS regeneration was skipped.

Existing ingress Docker objects were reused.

The application service remained:

```text
ghcr.io/alirasheedmd/platform-lab-web:sha-e18431842fa466381601851d4deb4380a01f8685@sha256:a1d870a474ef13f515253394c6e71ecc74db4d21f199b069d8d7875f1b50bfe7
```

This proved that configuration reconciliation did not overwrite the CI-owned application release.

---

# Repository Reproducibility

The rebuild also exposed a repository-state issue.

`configuration/ansible/inventory.ini` contained current public node addresses and was regenerated after infrastructure recreation.

Because the file was tracked by Git, a successful rebuild left the repository dirty.

The inventory is now treated as generated state:

```text
Terraform outputs
    ↓
generate-inventory.sh
    ↓
inventory.ini
    ↓
Ansible
```

`inventory.ini` exists locally when required but is gitignored.

The repository therefore tracks the generator rather than ephemeral cloud addressing.

This allows a successful rebuild to finish with:

```text
nothing to commit, working tree clean
```

---

# Dependency Closure

A key lesson from the clean-room rebuild is that success at one layer does not prove dependent layers are healthy.

The rebuild process therefore applies a dependency-closure check before moving forward.

Ask:

```text
What changed identity?

What external system references that identity?

What state survived destruction?

What state became stale?

What credential depends on the recreated resource?

What downstream system consumes this layer?

What evidence proves that downstream dependency still works?
```

For example:

```text
Manager recreated
    ↓
Public IP changed
SSH host key changed
    ↓
GitHub references became stale
    ↓
sync GitHub secrets
    ↓
run connectivity workflow
    ↓
only then trigger application deployment
```

This principle reduces the risk of hidden coupling during destructive operations.

---

# Reproducibility Acceptance Criteria

The platform is considered reproducible when all of the following are true:

```text
Infrastructure
[ ] Terraform reconstructs both nodes
[ ] Firewall is reconstructed
[ ] Terraform converges with no unexplained changes

Configuration
[ ] Fresh-node bootstrap completes
[ ] No unreachable hosts
[ ] No failed Ansible tasks
[ ] SSH hardening is applied
[ ] Docker is installed

Cluster
[ ] Manager is Ready / Active / Leader
[ ] Worker is Ready / Active
[ ] Overlay exists
[ ] lab-web converges to 4/4
[ ] lab-ingress converges to 2/2

Security / Connectivity
[ ] Deployment SSH key is installed
[ ] WireGuard is running
[ ] GitHub dynamic secrets are refreshed
[ ] Platform connectivity workflow passes

Ingress
[ ] HTTP redirects to HTTPS through both nodes
[ ] HTTPS responds successfully through both nodes

Release
[ ] GitHub Actions builds the application
[ ] Artifact is pushed to GHCR
[ ] Service image contains the Git SHA
[ ] Service image is pinned by digest
[ ] Swarm rollout converges
[ ] New application content is externally visible

Idempotency
[ ] Second bootstrap reports changed=0
[ ] No failed or unreachable hosts
[ ] Current CI release is preserved
[ ] TLS is not unnecessarily regenerated
[ ] Existing Swarm state is not unnecessarily recreated

Repository
[ ] Generated inventory is untracked
[ ] Bootstrap does not dirty the Git repository
```

---

# What Reproducibility Does Not Mean

Reproducibility does not mean:

- every dependency must be created by one tool,
- credentials should be committed,
- persistent identities must be destroyed during every test,
- all runtime state must be disposable,
- a successful `terraform apply` proves the application works,
- a successful CI run proves the public service works.

Instead, reproducibility means that dependencies and ownership are explicit and the complete system can be reconstructed predictably.

---

# Current Limitations

The current proof covers the stateless application and ingress path.

The lab does not yet claim that arbitrary stateful application data can be destroyed and reconstructed safely.

Any future stateful workloads require explicit consideration of:

- backup,
- restore,
- persistence,
- node-local volume behavior,
- replication,
- recovery point objectives,
- recovery time objectives.

The current Redis exercises demonstrated storage and scheduling behavior, but they should not be interpreted as a production-grade stateful recovery design.

Observability also remains a separate maturity area.

Prometheus, Grafana, Node Exporter and cAdvisor are not part of the currently proven clean-room rebuild path.

---

# Supporting Evidence

Historical ingress validation is recorded in:

```text
docs/validation/2026-09-17-ingress.md
```

The operational rebuild sequence is documented in:

```text
docs/runbooks/rebuild.md
```

A dedicated September 18 clean-room validation record should preserve the final evidence of:

- Terraform convergence,
- fresh bootstrap,
- external secret reconciliation,
- CI connectivity,
- immutable release deployment,
- public verification,
- operational idempotency.

---

# Operational Definition

For this lab:

```text
source-controlled infrastructure
        +
source-controlled platform configuration
        +
controlled external state
        +
explicit ownership boundaries
        +
repeatable reconciliation
        +
dependency-aware validation
        =
reproducible platform
```

The goal is not:

> "I know the commands required to rebuild the servers."

The goal is:

> "The platform can be destroyed, reconstructed, reconciled with its external dependencies, validated, released to, and safely reconciled again without depending on undocumented manual server state."
