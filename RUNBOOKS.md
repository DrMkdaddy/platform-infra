# RUNBOOKS.md — Failure procedures

Procedures for the failure modes this lab is built to survive. Each one names the
symptom, how it is detected, the repair, and the durable change that stops it recurring.

These are drills, not war stories. The point of running them here is that the first
time you meet the failure is not in production.

---

## 1. A bad NixOS generation is active

**Symptom:** the host boots or runs with a configuration that broke something
(service down, network misconfigured, SSH refused).

**Detection:** the service is unreachable, or `systemctl --failed` is non-empty after a
`nixos-rebuild switch`.

**Repair:**

```bash
# See what generations exist
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Roll back to the previous known-good generation
nixos-rebuild switch --rollback >/dev/null 2>&1 || \
  /nix/var/nix/profiles/system-<N-1>-link/bin/switch-to-configuration switch

reboot   # if the fault is in early boot
```

**Verification:** the failed unit is gone from `systemctl --failed`, and the service
answers on its port.

**Durable change:** fix the module in the repo, rebuild forward, and never hand-edit
the running system. The repo is the source of truth; the generation was a symptom.

**Probe to expect:** why does rollback work at the system level? What is a generation?

---

## 2. OpenTofu state has drifted from reality

**Symptom:** `tofu plan` wants to destroy or recreate a container that is obviously
still running, because someone changed it in the Proxmox UI.

**Detection:** a plan with unexpected `-/+ destroy and then create` on a resource that
should be untouched.

**Repair:**

```bash
cd tofu
tofu refresh                 # read reality back into state
tofu plan                    # read the diff before acting
# If the resource exists but is untracked:
tofu import proxmox_virtual_environment_container.worker <node>/<vm_id>
```

**Verification:** `tofu plan` reports no changes on a clean tree.

**Durable change:** the Proxmox UI is read-only in this workflow. Any real change is a
commit, review, and apply. Move state to a locking backend before a second operator
can apply.

**Probe to expect:** what happens when reality and state disagree? When is `force-unlock`
safe?

---

## 3. Disk pressure on the host

**Symptom:** writes fail, services degrade, the Nix store grows without bound.

**Detection:** node-exporter filesystem alerts, or a full `/nix` mount.

**Repair:**

```bash
df -h / /nix
sudo nix-collect-garbage --delete-older-than 7d
sudo nix-store --optimise
# Drop old generations if still tight
sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system
```

**Verification:** free space recovered, `systemctl --failed` empty.

**Durable change:** `nix.gc.automatic` is enabled in `modules/lab-host.nix`
(weekly, older than 14 days). Alert on filesystem usage, not on it being full.

**Probe to expect:** why does a Nix host grow differently from a package-manager host?

---

## 4. A container is OOM-killed

**Symptom:** the service restarts in a loop; logs end abruptly.

**Detection:** `systemctl status podman-stanza-api`, `dmesg | grep -i oom`, container
exit code 137.

**Repair:** raise the container memory bound deliberately, or fix the leak. Confirm
with `podman stats` under load.

**Verification:** sustained load no longer produces exit 137.

**Durable change:** resource bounds are declared, not defaulted. Add a load test that
runs before a service is considered healthy.

**Probe to expect:** how do you tell an OOM kill from a crash?

---

## 5. A service rollout is bad

**Symptom:** the new image or config is up but unhealthy.

**Detection:** the health endpoint fails; the port is closed; logs show startup errors.

**Repair:** revert the image tag or config in the repo, then rebuild and redeploy:

```bash
# Revert the change in git, then:
nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
```

**Verification:** the health endpoint returns 200 and stays up under load.

**Durable change:** pin image digests, not `latest`. A rollout returns to the previous
generation with one command.

**Probe to expect:** walk me through a rollback you actually performed.

---

## 6. Restore a host from backup

**Symptom:** a host is lost or corrupted and must be rebuilt.

**Detection:** the host is unreachable and not recoverable in place.

**Repair:**

```bash
# Re-provision the container/VM from the same OpenTofu plan
cd tofu && tofu apply
# Deploy the pinned configuration
nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
# Restore stateful data from the ZFS snapshot / backup target
```

**Verification:** services answer, data matches the last backup, and the host appears in
`tofu state list`.

**Durable change:** snapshot schedule plus a restore drill on the calendar. An untested
backup is a rumour.

**Probe to expect:** what are your RTO and RPO, and when did you last test them?