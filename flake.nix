{
  description = "My blog";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    gitignore,
    treefmt,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      treefmtEval = treefmt.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.toml-sort.enable = true;
        programs.mdformat.enable = true;
        programs.alejandra.enable = true;
        programs.actionlint.enable = true;
      };

      inherit (gitignore.lib) gitignoreSource;
    in {
      formatter = treefmtEval.config.build.wrapper;
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [marksman vale-ls (vale.withStyles (s: [s.write-good]))];
      };

      packages.default = pkgs.stdenvNoCC.mkDerivation {
        src = gitignoreSource ./.;
        strict = true;
        pname = "blog";
        doCheck = true;
        version = "none";
        nativeBuildInputs = with pkgs; [mdbook];
        buildPhase = ''
          mdbook build
        '';
        installPhase = ''
          mv book $out
        '';
      };

      checks = {
        grammar = pkgs.stdenvNoCC.mkDerivation {
          name = "grammar-check";
          strict = true;
          dontBuild = true;
          src = gitignoreSource ./.;
          doCheck = true;
          nativeBuildInputs = with pkgs; [(vale.withStyles (s: [s.write-good]))];
          checkPhase = ''
            vale **/*.md
          '';
          installPhase = ''
            mkdir $out
          '';
        };

        formatting = treefmtEval.config.build.check self;
      };
    });
}
