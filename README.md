# platform-infra

Declarative infrastructure for a private Proxmox VE lab. OpenTofu provisions the hosts,
NixOS configures them, and every failure mode has a documented recovery procedure.

## Overview

The stack is split by responsibility. Provisioning and configuration are separate
layers with separate tools, so neither can drift into the other.

| Layer | Tool | Responsibility |
| :-- | :-- | :-- |
| Provisioning | OpenTofu (`bpg/proxmox`) | containers, machines, storage, network |
| Configuration | NixOS flakes | host settings, services, users, firewall |
| Workloads | Podman (OCI) | container images declared in Nix |
| Observability | Prometheus node-exporter | host metrics |
| Operations | [`RUNBOOKS.md`](RUNBOOKS.md) | detection and recovery procedures |

```text
                    operator
                       |
          tofu plan / apply | nixos-rebuild
                       |
              +--------v---------+
              |  Proxmox VE node |
              |  API managed,    |
              |  no UI edits     |
              +--------+---------+
                       |
         +-------------v-----------------+
         |  lab-worker (NixOS)           |
         |  sshd  firewall  podman       |
         |  node-exporter                |
         |  +-------------------------+  |
         |  | stanza-api (container)  |  |
         |  +-------------------------+  |
         +-------------------------------+
```

## Principles

- The repository is the source of truth. The Proxmox web UI is a read-only view of
  what the code has already applied.
- No hand edits. A manual change is drift and is reverted on the next apply.
- Reproducible. Any host can be destroyed and rebuilt from this repository.
- Reversible. NixOS activates atomically; a bad configuration is one command from
  the previous generation.

## Repository layout

```text
flake.nix                       dev shell and NixOS host configurations
modules/lab-host.nix            shared host configuration
modules/stanza-service.nix      declarative service (typed options, systemd-managed)
nixos/lab-worker.nix            host definition
tofu/                           OpenTofu provisioning
  versions.tf  providers.tf  variables.tf  main.tf  outputs.tf
  terraform.tfvars.example
RUNBOOKS.md                     failure procedures
.github/workflows/ci.yml        format, validate, and flake checks
```

## Requirements

- Nix with flakes enabled. The dev shell supplies OpenTofu, tflint, and jq.
- A Proxmox VE node reachable over its API.
- An API token permitted to create containers on the target node.

## Provisioning

Create the API token on the Proxmox host:

```bash
pveum user token add tofu@pve provision --privsep 0
```

Apply the plan from the dev shell:

```bash
nix develop

export PROXMOX_VE_ENDPOINT=https://<node>:8006/
export PROXMOX_VE_API_TOKEN=<token-id>=<secret>

cd tofu
tofu init
tofu validate
tofu plan
tofu apply
```

`tofu plan` is safe to read. `tofu destroy` removes exactly the resources recorded in
state.

## Configuration

```bash
nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
```

Rollback to the previous generation:

```bash
nixos-rebuild switch --rollback
```

## Operations

[`RUNBOOKS.md`](RUNBOOKS.md) documents the failure modes this lab is built to survive
and the recovery for each: configuration rollback, OpenTofu state drift, disk
pressure, OOM kills, failed rollouts, and host restore. They are drilled on the same
hardware they describe.

## Continuous integration

`.github/workflows/ci.yml` runs on every push and pull request:

- `tofu fmt -check -recursive`, `tofu init -backend=false`, `tofu validate`
- `nix flake check --no-build --all-systems`
- markdown lint

## State

State is local for the lab. Before this manages shared infrastructure, move it to a
backend with locking so concurrent applies cannot conflict and state survives a
workstation failure.

## Scope

Lab and reference infrastructure. Self-hosted, no external customers, no paid tiers.
The Proxmox provider and the NixOS configuration are exercised on the same hardware
the runbooks describe.

## License

MIT. See [LICENSE](LICENSE).
