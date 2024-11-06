{
  description = "Utility functions for defining nix haskell flakes";

  outputs = { self }:
    let
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
        format-hs
        lint
        lint-refactor
        mkApp
        mkShellApp;
    };
}
