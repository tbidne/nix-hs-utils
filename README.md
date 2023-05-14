# Nix HS Utils

Nix utility functions for haskell flakes.

# Example usage

```nix
{
  description = "Some flake";
  inputs = {
    nix-hs-utils.url = "github:tbidne/nix-hs-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # top-level libs buildable w/ callCabal2nix
    lib1.url = "github:user/lib1";
    lib2.url = "github:user/lib2";

    # multiple libs in subdirs e.g. libs/sublib1, libs/sublib2
    # also buildable w/ callCabal2nix
    libs.url = "github:user/libs";
  };
  outputs =
    inputs@{ libs
    , nix-hs-utils
    , nixpkgs
    , self
    , ...
    }:
      let
        system = "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
        };

        ghc-version = "ghc944";
        compiler = pkgs.haskell.packages."${ghc-version}".override {
          overrides = final: prev: {
            # some normal overrides
            ormolu = prev.ormolu_0_5_3_0;
          } # adding lib1 lib2 deps
            // nix-hs-utils.mkLibs inputs final [
              "lib1"
              "lib2"
          ] # adding libs relative deps
            // nix-hs-utils.mkRelLibs libs final [
              "sublib1"
              "sublib2"
          ];
        };
        mkPkg = returnShellEnv:
          nix-hs-utils.mkHaskellPkg {
            inherit compiler pkgs returnShellEnv;
            name = "my-hs-pkg-name";
            root = ./.;
          };
        # used in below apps
        hs-dirs = "app src test";
    in
    {
      # builds exe/lib
      packages.default = mkPkg false;

      # dev shell w/ default build/dev tools
      devShells.default = mkPkg true;

      # formatting and linting
      apps = {
        format = nix-hs-utils.format {
          inherit compiler hs-dirs pkgs;
        };
        lint = nix-hs-utils.lint {
          inherit compiler hs-dirs pkgs;
        };
        lint-refactor = nix-hs-utils.lint-refactor {
          inherit compiler hs-dirs pkgs;
        };
      };
    };
}
```