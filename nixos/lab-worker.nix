# Host definition: lab-worker
#
# Provisioned by OpenTofu (see tofu/main.tf), configured here. Deploy with:
#   nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
{ config, lib, pkgs, ... }:

{
  imports = [ ];

  networking.hostName = "lab-worker";

  # Inject the operator key. Replace with the real public key before deploying.
  users.users.admin.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 AAAA... you@workstation"
  ];

  # The reference service this host exists to run.
  services.stanza.enable = true;
  services.stanza.port = 8787;

  # Pinned for reproducibility. Change deliberately, never implicitly.
  system.stateVersion = "24.11";
}