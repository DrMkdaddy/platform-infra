# platform-infra

Declarative infrastructure for a private Proxmox VE lab and the cloud reference
build that follows it.

The split is deliberate:

- **OpenTofu provisions the resource.** Machines, containers, storage, network,
  and the cloud resources built on top, all described in HCL and reconciled with
  `plan` / `apply`.
- **NixOS configures the machine.** Flake-based host configuration, atomic
  activation, rollback for free. The host definition never drifts from the repo.

Nothing here is clicked through the Proxmox web UI. The web UI is a read-only
view of what this code has already done.

## Why it is built this way

Infrastructure that only exists in a hypervisor console cannot be reviewed,
diffed, recreated, or rolled back. Every change here is a commit that a second
engineer can read before it runs, and every resource can be destroyed and
rebuilt from the same source.

## Layout

```
flake.nix                     devShell: opentofu, tflint, jq
tofu/
  versions.tf                 provider and version constraints, state backend
  providers.tf                Proxmox provider wiring
  variables.tf                inputs, secrets marked sensitive
  main.tf                     the managed container
  outputs.tf                  values exported after apply
  terraform.tfvars.example    template for local credentials
```

## Prerequisites

- Nix with flakes enabled (the devShell supplies OpenTofu)
- A Proxmox VE node reachable over its API
- An API token with permission to create containers on the target node

Create the token on the node (run as root on the Proxmox host):

```bash
pveum user token add tofu@pve provision --privsep 0
```

## Usage

Enter the devShell:

```bash
nix develop
```

Export credentials. These are read by the provider and never written to disk:

```bash
export PROXMOX_VE_ENDPOINT=https://<node>:8006/
export PROXMOX_VE_API_TOKEN=<token-id>=<secret>
```

Then the standard loop from `tofu/`:

```bash
cd tofu
tofu init
tofu validate
tofu plan
tofu apply
```

`tofu plan` is safe to read. `tofu apply` creates the container. Teardown is
`tofu destroy`, which removes exactly what the state file tracks.

## State

State is local for the lab. Before this touches anything shared or cloud, move
it to a remote backend (S3 or Postgres) with locking, so two operators cannot
apply at once and so state survives a workstation failure.

## Roadmap

1. Lab containers under OpenTofu. In progress.
2. Machine configuration moved to NixOS flakes per host.
3. Cloud reference build: the same pattern with remote state, CI plan/apply,
   monitoring, backups, and a written failure/recovery runbook.

## Status

Lab and reference work only. Self-hosted, no external customers, no paid tiers.
