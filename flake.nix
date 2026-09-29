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
        "x86_64-darwin"
        "aarch64-darwin"
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
    };
}
