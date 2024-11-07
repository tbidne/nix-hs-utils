# Nix HS Utils

[![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/tbidne/nix-hs-utils?include_prereleases&sort=semver&labelColor=2f353e)](https://github.com/tbidne/nix-hs-utils/releases/)
[![ci](http://img.shields.io/github/actions/workflow/status/tbidne/nix-hs-utils/ci.yaml?branch=main)](https://github.com/tbidne/nix-hs-utils/actions/workflows/ci.yaml)
[![MIT](https://img.shields.io/github/license/tbidne/nix-hs-utils?color=blue&labelColor=2f353e)](https://opensource.org/licenses/MIT)

---

Nix utility functions for haskell flakes.

# Schema

## Functions

### High level

* `mkLibs` and `mkRelLibs`: convenience functions for adding packages built by `callCabal2nix`.
* `mkDevTools`: returns a list with:
  * formatters: `cabal-fmt`, `fourmolu`, `nixpkgs-fmt`/`nixfmt`, `ormolu`.
  * linters: `hlint` (with `apply-refact`).
  * `haskell-language-server`.
* `mkHaskellPkg`: Wrapper for `developPackage`. Returns either a development shell or a derivation, depending on the value of `returnShellEnv`. Uses `mkDevTools` by default.

### Low level

* `mkLib` and `mkRelLib`: singular versions of `mkLibs` and `mkRelLibs`, respectively.
* `mkBuildTools`: function returning a list of `cabal` and `zlib`.

## Apps

### High level

* `format`: formats `*.cabal`, `*.nix`, and `*.hs` (`ormolu` or `fourmolu`).
* `format-hs`: formats `*.hs` (`ormolu` or `fourmolu`).
* `format-yaml`: formats `*.yaml` (`prettier`).
* `lint`: Runs `hlint` on `*.hs`.
* `lint-refactor`: Runs `hlint` on `*.hs`, refactoring suggestions.
* `lint-yaml`: Runs `yamllint` on `.`.

### Low level

* `mkShellApp`: Makes an app via `writeShellApplication`.
* `mkApp`: Makes an app via a derivation.

# Example usage

```nix
{
  description = "A flake for a haskell package";
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
    inputs@{ nix-hs-utils
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
          ] # adding libs' relative deps
            // nix-hs-utils.mkRelLibs inputs.libs final [
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
    in
    {
      # builds exe/lib
      packages."${system}".default = mkPkg false;

      # dev shell w/ default build/dev tools
      devShells."${system}".default = mkPkg true;

      # formatting and linting
      apps = {
        format = nix-hs-utils.format {
          inherit compiler pkgs;
          # hsFmt = "fourmolu"; # defaults to ormolu
        };
        # Formats haskell files only
        format-hs = nix-hs-utils.format-hs {
          inherit compiler pkgs;
        };
        # Use find over fd. Probably want to explicitly pass in dirs
        # (findHsArgs) in this case.
        formatFind = nix-hs-utils.format {
          inherit compiler pkgs;
          findHsArgs = "app src test";
          fd = false;
        };
        lint = nix-hs-utils.lint {
          inherit compiler pkgs;
        };
        lint-refactor = nix-hs-utils.lint-refactor {
          inherit compiler pkgs;
        };
      };
    };
}
```

Note that we can also merge multiple apps together, using the `mkDrv` argument (default `true`) and `mergeApps`:

```nix
let
  # mergeApps takes in a list of app AttrSet and merges them together into a
  # single app.
  format = nix-hs-utils.mergeApps {
    apps = [
      # setting 'mkDrv = false' means that instead of the derivation, we
      # will return the preliminary set.
      (nix-hs-utils.format ({ ... mkDrv = false; ... }))
      (nix-hs-utils.format-yaml ({ ... mkDrv = false; ... }))
    ];
  };
```
