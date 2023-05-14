let
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
in
{
  inherit
    mkApp
    mkShellApp
    format
    lint
    lint-refactor;
}
