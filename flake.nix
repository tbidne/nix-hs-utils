{
  description = "Utility functions for defining nix haskell flakes";

  # nix
  inputs.flake-compat = {
    url = "github:edolstra/flake-compat";
    flake = false;
  };
  outputs = { flake-compat, self }:
    let
      # Makes a library from source e.g.
      #
      # inputs.some-hs-lib.url = "github:user/some-hs-lib";
      # compiler = pkgs.haskell.packages."${ghc-version}".override {
      #   overrides = final: prev: {
      #     some-hs-lib = nix-hs-utils.mkLib inputs final "some-hs-lib";
      #   }
      # };
      mkLib = inputs: p: lib: p.callCabal2nix lib inputs."${lib}" { };
      # Makes a library from a relative source e.g.
      #
      # # i.e. path is some-hs-libs/sub-dir-lib
      # inputs.some-hs-libs.url = "github:user/some-hs-libs";
      # compiler = pkgs.haskell.packages."${ghc-version}".override {
      #   overrides = final: prev: {
      #     sub-dir-lib = nix-hs-utils.mkRelLib some-hs-libs final "sub-dir-lib"
      #   }
      # };
      mkRelLib = rel: p: lib: p.callCabal2nix lib "${rel}/${lib}" { };
      # Turns a list of libs into an attr set via mkLib e.g.
      #
      # inputs.some-hs-lib1.url = "github:user/some-hs-lib1";
      # compiler = pkgs.haskell.packages."${ghc-version}".override {
      #   overrides = final: prev: {
      #     ...
      #   } // nix-hs-utils.mkRelLibs monad-effects final [
      #     "some-hs-lib1"
      #     "some-hs-lib2"
      #   ];
      # };
      mkLibs = inputs: p: libs:
        builtins.foldl' (acc: name: acc // { ${name} = mkLib inputs p name; }) { } libs;
      # Turns a list of relative libs into an attr set via mkRelLib e.g.
      #
      # # i.e. paths are some-hs-libs/sub-dir-lib1 and some-hs-libs/sub-dir-lib2
      # inputs.some-hs-libs.url = "github:user/some-hs-libs";
      # compiler = pkgs.haskell.packages."${ghc-version}".override {
      #   overrides = final: prev: {
      #     ...
      #   } // nix-hs-utils.mkRelLibs some-hs-libs final [
      #     "sub-dir-lib1"
      #     "sub-dir-lib2"
      #   ];
      # };
      mkRelLibs = rel: p: libs:
        builtins.foldl' (acc: x: acc // { ${x} = mkRelLib rel p x; }) { } libs;

      # Cabal and zlib
      mkBuildTools = pkgs: c: [
        c.cabal-install
        pkgs.zlib
      ];
      # Formatters (cabal-fmt, nixpkgs-fmt, ormolu)
      # Linter (HLint + refactor)
      # HLS
      mkDevTools = pkgs: c:
        let hlib = pkgs.haskell.lib; in [
          (hlib.dontCheck c.apply-refact)
          (hlib.dontCheck c.cabal-fmt)
          (hlib.dontCheck c.haskell-language-server)
          (hlib.dontCheck c.hlint)
          (hlib.dontCheck c.ormolu)
          pkgs.nixpkgs-fmt
        ];
      # Makes a haskell package via developPackage. The default derivation
      # uses mkDevTools and mkBuildTools.
      mkHaskellPkg =
        { name
        , compiler
        , pkgs
        , returnShellEnv
        , root
        , modifier ? drv:
            pkgs.haskell.lib.addBuildTools drv
              (mkBuildTools pkgs compiler ++
                (if returnShellEnv then mkDevTools pkgs compiler else [ ]))
        }:
        compiler.developPackage {
          inherit name root modifier returnShellEnv;
        };
      # Convenience function for making an app from a derivation.
      mkApp = drv: {
        type = "app";
        program = "${drv}/bin/${drv.name}";
      };
      # Convenience function for making an app from a writeShellApplication.
      mkShellApp =
        { name
        , pkgs
        , text
        , runtimeInputs
        }:
        mkApp (
          pkgs.writeShellApplication {
            inherit name text runtimeInputs;
          }
        );
    in
    {
      inherit
        mkLib
        mkRelLib
        mkLibs
        mkRelLibs
        mkBuildTools
        mkDevTools
        mkHaskellPkg
        mkApp
        mkShellApp;

      # ShellApp that formats cabal, nix, and haskell via ormolu.
      format =
        { compiler
        , hs-dirs
        , pkgs
        , name ? "format"
        }:
        mkShellApp {
          inherit name pkgs;
          text = ''
            set -e

            export LANG="C.UTF-8"

            nixpkgs-fmt ./

            # shellcheck disable=SC2046
            cabal-fmt --inplace $(find . -type f -name '*cabal')

            # shellcheck disable=SC2046,SC2086
            ormolu -m inplace $(find ${hs-dirs} -type f -name '*.hs')
          '';
          runtimeInputs = [
            compiler.cabal-fmt
            compiler.ormolu
            pkgs.nixpkgs-fmt
          ];
        };

      # ShellApp that runs hlint on hs-dirs.
      lint =
        { compiler
        , hs-dirs
        , pkgs
        , name ? "lint"
        }:
        mkShellApp {
          inherit name pkgs;
          text = ''
            set -e

            export LANG="C.UTF-8"

            # shellcheck disable=SC2046,SC2086
            hlint $(find ${hs-dirs} -type f -name "*.hs")
          '';
          runtimeInputs = [ compiler.hlint ];
        };

      # ShellApp that runs hlint + refactor on hs-dirs.
      lint-refactor =
        { compiler
        , hs-dirs
        , pkgs
        , name ? "lint-refactor"
        }:
        mkShellApp {
          inherit name pkgs;
          text = ''
            set -e

            export LANG="C.UTF-8"

            # shellcheck disable=SC2038,SC2086
            find ${hs-dirs} -type f -name "*.hs" | xargs -I % sh -c " \
              hlint \
              --ignore-glob=dist-newstyle \
              --ignore-glob=stack-work \
              --refactor \
              --with-refactor=refactor \
              --refactor-options=-i \
              %"
          '';
          runtimeInputs = [ compiler.apply-refact compiler.hlint ];
        };
    };
}
