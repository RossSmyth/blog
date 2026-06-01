{
  system ? builtins.currentSystem or "x86_64-linux",
}:
let
  inputs = import ./npins { };

  pkgs = import inputs.nixpkgs {
    hostSystem.system = system;
  };

  fs = pkgs.lib.fileset;
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "blog";
  version = "none";

  src = fs.toSource {
    root = ./.;
    fileset = fs.unions [
      ./src
      ./book.toml
    ];
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
}
