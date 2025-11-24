{
  description = "My blog";
  inputs = {
    nixpkgs.url = "https://nixos.org/channels/nixos-unstable/nixexprs.tar.xz";

    treefmt = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt,
    }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      treefmtEval = treefmt.lib.evalModule pkgs {
        projectRootFile = "flake.nix";
        programs.toml-sort.enable = true;
        programs.mdformat = {
          enable = true;
          settings.wrap = 80;
        };
        programs.nixfmt.enable = true;
        programs.actionlint.enable = true;
      };

      fs = pkgs.lib.fileset;
    in
    {
      formatter.${system} = treefmtEval.config.build.wrapper;

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          marksman
          vale-ls
          (vale.withStyles (s: [ s.write-good ]))
        ];
      };

      packages.${system}.default = pkgs.stdenvNoCC.mkDerivation {
        pname = "blog";
        version = "none";

        src = fs.toSource {
          root = ./.;
          fileset = fs.difference ./. (
            fs.unions [
              ./.gitignore
              ./flake.nix
              ./flake.lock
              ./.vale.ini
            ]
          );
        };

        strictDeps = true;
        nativeBuildInputs = with pkgs; [
          mdbook
          mdbook-pagetoc
        ];
        buildPhase = ''
          mdbook build
        '';
        installPhase = ''
          mv book $out
        '';
      };

      checks.${system} = {
        grammar = pkgs.stdenvNoCC.mkDerivation {
          name = "grammar-check";

          src = fs.toSource {
            root = ./.;
            fileset = fs.difference ./. (
              fs.unions [
                ./.gitignore
                ./flake.nix
                ./flake.lock
              ]
            );
          };

          strictDeps = true;
          dontBuild = true;
          doCheck = true;

          nativeCheckInputs = with pkgs; [ (vale.withStyles (s: [ s.write-good ])) ];

          checkPhase = ''
            vale **/*.md
          '';
          installPhase = ''
            touch $out
          '';
        };

        formatting = treefmtEval.config.build.check self;
      };
    };
}
