# Shared configuration for every machine in the lab.
#
# The host is configured from this file, not by hand. A rebuild either succeeds
# and activates atomically, or it fails and the previous generation keeps
# running. Rollback is `nixos-rebuild switch --rollback`.
{ config, lib, pkgs, ... }:

{
  # --- Access -------------------------------------------------------------
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- Identity -----------------------------------------------------------
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Public keys are injected per-host; see nixos/<host>.nix.
    openssh.authorizedKeys.keys = [ ];
  };

  security.sudo.wheelNeedsPassword = false;

  # --- Network ------------------------------------------------------------
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # --- Runtime ------------------------------------------------------------
  # Podman runs the OCI workloads declared in modules/stanza-service.nix.
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  # --- Observability ------------------------------------------------------
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
    enabledCollectors = [ "systemd" "processes" "filesystem" "diskstats" ];
  };

  # --- Maintenance --------------------------------------------------------
  # Unattended store cleanup keeps the closure set bounded on a small disk.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.trusted-users = [ "admin" ];

  environment.systemPackages = with pkgs; [
    curl
    htop
    jq
    vim
  ];
}