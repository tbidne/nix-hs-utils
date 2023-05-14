{
  description = "Utility functions for defining nix haskell flakes";

  # nix
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };
  outputs = { flake-compat, self }:
    let
      apps = import lib/apps.nix;
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
      inherit (apps) format
        lint lint-refactor mkApp mkShellApp;
    };
}
