# platform-infra

Declarative infrastructure for a private Proxmox VE lab: OpenTofu provisions the
machines, NixOS configures them, and every failure mode has a written procedure.

The split is deliberate:

- **OpenTofu provisions the resource.** Containers, machines, storage, and network
  are described in HCL and reconciled with `plan` / `apply`.
- **NixOS configures the machine.** Flake-based host configuration, atomic
  activation, rollback for free. The host definition never drifts from the repo.

Nothing here is clicked through the Proxmox web UI. The web UI is a read-only view
of what the code has already done.

## Why it is built this way

Infrastructure that only exists in a hypervisor console cannot be reviewed, diffed,
recreated, or rolled back. Every change here is a commit a second engineer can read
before it runs, and every resource can be destroyed and rebuilt from the same source.

The second reason is failure practice. [`RUNBOOKS.md`](RUNBOOKS.md) covers the modes
this lab is built to survive: a bad NixOS generation, OpenTofu state drift, disk
pressure, an OOM kill, a bad rollout, and a full host restore. A runbook that has
never been run is a guess, so they are meant to be drilled.

## Layout

```
flake.nix                       devShell + NixOS host configurations
modules/
  lab-host.nix                  shared host config: ssh, firewall, podman, node-exporter
  stanza-service.nix            declarative service (typed options, systemd-managed)
nixos/
  lab-worker.nix                one host definition
tofu/
  versions.tf                   provider and version constraints, state backend
  providers.tf                  Proxmox provider wiring
  variables.tf                  inputs, secrets marked sensitive
  main.tf                       the managed container
  outputs.tf                    values exported after apply
  terraform.tfvars.example      template for local credentials
RUNBOOKS.md                     failure procedures
.github/workflows/ci.yml        tofu fmt/validate, nix flake check, markdown lint
```

## Prerequisites

- Nix with flakes enabled (the devShell supplies OpenTofu)
- A Proxmox VE node reachable over its API
- An API token with permission to create containers on the target node

Create the token on the node (run as root on the Proxmox host):

```bash
pveum user token add tofu@pve provision --privsep 0
```

## Provision the resource

```bash
nix develop
export PROXMOX_VE_ENDPOINT=https://<node>:8006/
export PROXMOX_VE_API_TOKEN=<token-id>=<secret>

cd tofu
tofu init
tofu validate
tofu plan      # safe to read
tofu apply     # creates the container
```

Teardown is `tofu destroy`, which removes exactly what the state file tracks.

## Configure the machine

```bash
nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
```

Rollback is `nixos-rebuild switch --rollback`.

## State

State is local for the lab. Before this touches anything shared, move it to a remote
backend with locking, so two operators cannot apply at once and so state survives a
workstation failure.

## Status

Lab and reference work only. Self-hosted, no external customers, no paid tiers.
The Proxmox provider and NixOS configuration are the parts that get exercised; the
runbooks are drilled on the same hardware they describe.