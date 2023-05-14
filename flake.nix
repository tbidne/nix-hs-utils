{
  description = "Utility functions for defining nix haskell flakes";

  # nix
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = { flake-compat, nixpkgs, self }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      libApps = import lib/apps.nix;
      misc = import lib/misc.nix;
    in
    {
      inherit (misc)
        mkLib
        mkRelLib
        mkLibs
        mkRelLibs
        mkBuildTools
        mkDevTools
        mkHaskellPkg;
      inherit (libApps)
        format
        lint
        lint-refactor
        mkApp
        mkShellApp;

      apps."${system}" = {
        format = libApps.mkShellApp {
          inherit pkgs;
          name = "format";
          text = "nixpkgs-fmt ./";
          runtimeInputs = [ pkgs.nixpkgs-fmt ];
        };
      };
    };
}
