# Runbooks

Operational procedures for `platform-infra`. Each entry states the failure, how it is
detected, the recovery, the validation that the failure is cleared, and the prevention
that stops it recurring.

These are procedures, not incident records. They target the same hardware they
describe. A recovery that has never been run is an assumption, not a capability.

| # | Failure | Impact |
| :-- | :-- | :-- |
| 1 | Bad NixOS generation | host runs a broken configuration |
| 2 | OpenTofu state drift | plan proposes destructive changes |
| 3 | Disk pressure | writes fail, services degrade |
| 4 | Container OOM kill | service restarts in a loop |
| 5 | Failed service rollout | new image or config is unhealthy |
| 6 | Host loss or corruption | host must be rebuilt |

---

## 1. Revert a bad NixOS generation

**Impact:** the host runs a configuration that broke a service, the network, or SSH.

**Detection:** the affected service is unreachable, or `systemctl --failed` is non-empty
after a `nixos-rebuild switch`.

**Recovery:**

```bash
nix-env --list-generations --profile /nix/var/nix/profiles/system
nixos-rebuild switch --rollback
# If early boot is affected, activate the previous generation directly and reboot:
/nix/var/nix/profiles/system-<N-1>-link/bin/switch-to-configuration switch
reboot
```

**Validation:** the failed unit no longer appears in `systemctl --failed`, and the
service responds on its port.

**Prevention:** fix the module in the repository and rebuild forward. The generation was
a symptom; the repository is the source of truth.

---

## 2. Reconcile OpenTofu state drift

**Impact:** `tofu plan` proposes destroying or recreating a resource that is still
running, because it was changed outside the code.

**Detection:** a plan containing an unexpected `-/+ destroy and then create`.

**Recovery:**

```bash
cd tofu
tofu refresh                                  # read reality into state
tofu plan                                     # inspect the diff before acting
tofu import proxmox_virtual_environment_container.worker <node>/<vm_id>   # if untracked
```

**Validation:** `tofu plan` reports no changes on a clean tree.

**Prevention:** the Proxmox UI is read-only in this workflow; every real change is a
commit, a review, and an apply. Move state to a locking backend before a second
operator can apply.

---

## 3. Recover from disk pressure

**Impact:** writes fail, services degrade, and the Nix store grows without bound.

**Detection:** node-exporter filesystem alerts, or a full `/nix` mount.

**Recovery:**

```bash
df -h / /nix
nix-collect-garbage --delete-older-than 7d
nix-store --optimise
nix-env --delete-generations old --profile /nix/var/nix/profiles/system
```

**Validation:** free space is recovered and `systemctl --failed` is empty.

**Prevention:** `nix.gc.automatic` is enabled in `modules/lab-host.nix` (weekly, older
than 14 days). Alert on filesystem usage before it reaches capacity.

---

## 4. Recover a container from an OOM kill

**Impact:** the service restarts in a loop and requests fail during the gaps.

**Detection:** container exit code 137, `dmesg | grep -i oom`, or an abrupt end to the
service log.

**Recovery:** raise the memory bound deliberately or fix the leak, then confirm the
new bound under load with `podman stats`.

**Validation:** sustained load no longer produces exit code 137.

**Prevention:** resource bounds are declared, not defaulted. A load test runs before a
service is considered healthy.

---

## 5. Roll back a failed service deployment

**Impact:** a new image or configuration is running but unhealthy.

**Detection:** the health endpoint fails, the port is closed, or logs show startup
errors.

**Recovery:** revert the failing change in the repository and redeploy.

```bash
git revert <commit>
nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
```

**Validation:** the health endpoint returns 200 and stays up under load.

**Prevention:** pin image digests rather than a moving tag. A rollout returns to the
previous generation with one command.

---

## 6. Restore a host from backup

**Impact:** a host is lost or corrupted and must be rebuilt.

**Detection:** the host is unreachable and cannot be recovered in place.

**Recovery:**

```bash
cd tofu && tofu apply                          # re-provision from the same plan
nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
# restore stateful data from the ZFS snapshot or backup target
```

**Validation:** services respond, data matches the last backup, and the host appears in
`tofu state list`.

**Prevention:** a snapshot schedule plus a restore drill on the calendar. An untested
backup is not a backup.
