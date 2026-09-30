{
  description = "Declarative infrastructure: OpenTofu provisioning, NixOS machine configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            opentofu
            tflint
            jq
          ];

          shellHook = ''
            echo "opentofu  $(tofu version | head -n1 | cut -d' ' -f2)"
            echo "tflint    $(tflint --version | head -n1 | awk '{print $3}')"
            echo
            echo "Set the Proxmox credentials before planning:"
            echo "  export PROXMOX_VE_ENDPOINT=https://<node>:8006/"
            echo "  export PROXMOX_VE_API_TOKEN=<token-id>=<secret>"
          '';
        };
      });

      # Reusable host configuration, shared by every lab machine.
      nixosModules.lab-host = import ./modules/lab-host.nix;
      # Declarative service definitions that run on top of a lab host.
      nixosModules.stanza-service = import ./modules/stanza-service.nix;

      # A single lab worker. Apply the OpenTofu plan first, then deploy config:
      #   nixos-rebuild switch --flake .#lab-worker --target-host admin@<ip>
      nixosConfigurations.lab-worker = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          self.nixosModules.lab-host
          self.nixosModules.stanza-service
          ./nixos/lab-worker.nix
        ];
      };
    };
}