{
  description = "My blog";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    gitignore,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      inherit (gitignore.lib) gitignoreSource;
    in {
      formatter = pkgs.alejandra;

      packages.default = pkgs.stdenvNoCC.mkDerivation {
        src = gitignoreSource ./.;
        pname = "blog";
        version = "none";
        buildInputs = with pkgs; [mdbook];
        buildPhase = ''
          mdbook build
        '';
        installPhase = ''
          mv book $out
        '';
      };
    });
}
