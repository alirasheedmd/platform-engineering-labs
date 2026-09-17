# Lab reproducibility

The operational target is two Swarm nodes, a private `lab-web` service with four
replicas, and two `lab-ingress` replicas exposing HTTP/HTTPS. Ingress redirects
HTTP to HTTPS and proxies requests to `lab-web:80` over `platform-overlay`.

## Ownership and prerequisites

- Terraform owns DigitalOcean compute, networking and firewall rules.
- Ansible owns the OS, Swarm, initial application service and HTTPS ingress.
- GitHub Actions owns the application release, using a SHA tag plus digest.
- Credentials and Terraform state are external inputs. Never commit private keys.

Install Ansible (validated with ansible-core 2.21.3) and the pinned collections:

```bash
ansible-galaxy collection install -r configuration/ansible/requirements.yml
```

Terraform credentials, state, SSH access and the usual cloud variable inputs must
already be available. Run provisioning from `infrastructure/terraform`. For a fresh
bootstrap, use an administrative SSH key attached to the new droplets, not a
deployment key that has not yet been installed there.

## Configure the current lab

From `configuration/ansible`, using the administrative SSH key installed by the
bootstrap role on both nodes:

```bash
ssh-add ~/.ssh/id_ed25519
ansible-playbook -u platform --private-key ~/.ssh/id_ed25519 playbooks/site.yml
```

Unlock the administrative key in your terminal first if it has a passphrase.
Ansible runs non-interactively and cannot prompt for the private-key passphrase.

This configures Swarm, reconciles `lab-web`, adopts/creates TLS and ingress, then
verifies the result. It removes any published application ports while preserving
the existing application image. On fresh infrastructure only, the initial
application uses the pinned Nginx image in `vars/lab.yml`. Application delivery
still requires the GitHub Actions release workflow. Do not run bootstrap and a
release deployment concurrently.

Run the same command a second time. With unchanged inputs, the recap should show
`changed=0`, `failed=0` and `unreachable=0`. Certificate renewal is an intentional
exception when the certificate is within seven days of expiry.

For the full existing bootstrap entry point, export the selected SSH key first:

```bash
export ANSIBLE_PRIVATE_KEY_FILE="$HOME/.ssh/id_ed25519"
./scripts/bootstrap-lab.sh
```

The inventory generator now resolves paths from its own location, so bootstrap
can be invoked from another working directory.

The CI deployment key (`~/.ssh/platform-lab-deploy`) is authorized only on the
manager in the existing lab. It can configure the service/ingress layer with
`playbooks/services.yml playbooks/ingress.yml playbooks/verify.yml`, but it cannot
run the worker portion of `site.yml` or the complete bootstrap.

## TLS lifecycle

`vars/lab.yml` declares the hostname, validity/renewal windows, image digest and
manager storage directory. The default certificate is self-signed for
`platform-lab.local`; it is not a publicly trusted certificate.

On the original lab, both `tls.crt` and `tls.key` are adopted from
`/home/platform/platform-ingress` into root-owned `/opt/platform/ingress`. Existing
managed files are not overwritten by this migration. The original files are left
in place. On a fresh manager, Ansible generates the key and certificate there.
The directory is mode `0700`; the key is mode `0600`. No key is copied to the
controller. Secret operations suppress Ansible output and diffs.

The public Nginx config and certificate become Docker Configs; the private key
becomes a Docker Secret mounted at `/run/secrets/tls.key` with mode `0400`.
Object names use hashes of public content. A certificate renewal creates new
objects and updates ingress. Unchanged content reuses the same objects. Previous
objects remain available for rollback; remove them only after checking they are
not referenced by current or previous service specifications.

Docker's [secret lifecycle documentation](https://docs.docker.com/engine/swarm/secrets/)
describes immutable secrets and granting a service access to a replacement secret.

Before the service is updated, `nginx -t` runs in a temporary container on the
manager using read-only mounts. Ingress updates one replica at a time and requests
automatic rollback on rollout failure. Verification rejects paused or rolled-back
updates and checks HTTP behavior as well as service state.

Certificate trust is explicit: verification uses `curl --cacert` and `--resolve`,
never `curl -k`. A rebuild generates a new self-signed identity unless an existing
certificate/key pair is restored securely on the manager. Public clients must
trust the new certificate after regeneration or renewal.

## Verify without changing service configuration

```bash
cd configuration/ansible
ansible-playbook -u platform --private-key ~/.ssh/platform-lab-deploy playbooks/verify.yml
```

The check requires the expected nodes to be ready/active, private application
access, the expected replica counts and image consistency, current config/secret
mounts, HTTP-to-HTTPS redirects, and certificate-validated HTTP 200 responses
through each node's VPC address. To require a specific application release, pass:

```bash
ansible-playbook -u platform --private-key ~/.ssh/platform-lab-deploy \
  playbooks/verify.yml -e 'lab_expected_web_image=ghcr.io/alirasheedmd/platform-lab-web:sha-COMMIT@sha256:DIGEST'
```

Replace the example image with the release's real tag and digest. An internal
check does not prove internet firewall reachability; also test each public node
address from an external client using the public certificate and `curl --resolve`.

Use `--syntax-check` before applying edits. `--check` is useful for an already
configured manager; a fresh TLS run needs actual files and Docker object IDs and
cannot be fully simulated by Ansible check mode.

## Remaining rebuild gates

This change closes private application access and ingress/TLS automation. A full
destroy/rebuild proof still needs:

1. Server-side WireGuard installation/configuration and peer-key recovery.
2. Deployment SSH public-key provisioning and portable administrative key inputs.
3. Refreshing GitHub secrets for a rebuilt manager's endpoint, WireGuard identity
   and SSH host key, plus GHCR authentication and a repeatable release trigger.
4. A reviewed application health/update/rollback policy. The existing application
   image and service policies are retained; the image supplies its health check.
5. Review of any stateful workloads and backup requirements before destruction.
6. A clean rebuild followed by these checks and an end-to-end GitHub Actions run.

Do not treat successful configuration of the existing lab as proof of a clean
rebuild. Terraform and Docker package versions, plus the historical README roadmap,
also need review before declaring the whole lab complete.

Live validation evidence is recorded in
[the September 17 ingress check](validation/2026-09-17-ingress.md).
