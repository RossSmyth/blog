{
  system ? builtins.currentSystem or "x86_64-linux",
}:
let
  inputs = import ./npins { };

  pkgs = import inputs.nixpkgs {
    hostSystem.system = system;
  };

  treefmt = import inputs.treefmt;

  treefmtEval = treefmt.evalModule pkgs {
    projectRootFile = "default.nix";
    programs.toml-sort.enable = true;
    programs.mdformat = {
      enable = true;
      settings.wrap = 80;
    };
    programs.nixfmt.enable = true;
    programs.actionlint.enable = true;
  };
in
pkgs.mkShellNoCC {
  packages = with pkgs; [
    marksman
    vale-ls
    (vale.withStyles (s: [ s.write-good ]))
    treefmtEval.config.build.wrapper
  ];
}
