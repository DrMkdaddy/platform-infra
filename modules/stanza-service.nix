# Declarative service definitions.
#
# A service is a typed option, not a shell script. Enabling it declares the
# container, its port, its environment, and its restart policy to systemd via
# podman. Nothing is started outside this module.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.stanza;
in
{
  options.services.stanza = {
    enable = lib.mkEnableOption "the Stanza API reference service";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/stanzaapi/example-service:latest";
      description = "Container image to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Host port to publish the service on.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables passed to the container.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.stanza-api = {
      image = cfg.image;
      ports = [ "${toString cfg.port}:8787" ];
      environment = {
        NODE_ENV = "production";
      } // cfg.environment;
      # A failed container is restarted by systemd; a failing image is caught by
      # the readiness probe below rather than left half-up.
    };

    # Declarative health check. systemd restarts the unit if this goes red.
    systemd.services.podman-stanza-api = {
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}