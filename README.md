# platform-infra

Declarative infrastructure for a private Proxmox VE lab. OpenTofu provisions
containers and VMs, NixOS configures the host, and each known failure mode has a
runbook.

## Overview

Provisioning and configuration are separate layers with separate tools.

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

## Rules

- All changes go through the repository. The Proxmox web UI is read-only.
- Manual changes are drift and are reverted on the next apply.
- A host can be destroyed and rebuilt from this repository.
- NixOS activates atomically; rollback is one command.

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

[`RUNBOOKS.md`](RUNBOOKS.md) documents the failure modes and recovery steps:
configuration rollback, OpenTofu state drift, disk pressure, OOM kills, failed
rollouts, and host restore.

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

Lab and reference infrastructure; no external customers.

## License

MIT. See [LICENSE](LICENSE).
