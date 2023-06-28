let
  utils = import ./utils.nix;

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
  inherit mkApp mkShellApp;

  # ShellApp that formats cabal, nix, and haskell via ormolu (default) or
  # fourmolu.
  format =
    { compiler
    , hsDirs
    , pkgs
    , name ? "format"
    , hsFmt ? "ormolu"
    }:
    let
      hsFmt' = utils.getHsFmt hsFmt;
    in
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        nixpkgs-fmt ./

        # shellcheck disable=SC2046
        cabal-fmt --inplace $(find . -type f -name '*cabal')

        # shellcheck disable=SC2046,SC2086
        ${hsFmt'.text hsDirs}
      '';
      runtimeInputs = [
        compiler.cabal-fmt
        (hsFmt'.dep compiler)
        pkgs.nixpkgs-fmt
      ];
    };

  # ShellApp that runs hlint on hsDirs.
  lint =
    { compiler
    , hsDirs
    , pkgs
    , name ? "lint"
    }:
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2046,SC2086
        hlint $(find ${hsDirs} -type f -name "*.hs")
      '';
      runtimeInputs = [ compiler.hlint ];
    };

  # ShellApp that runs hlint + refactor on hsDirs.
  lint-refactor =
    { compiler
    , hsDirs
    , pkgs
    , name ? "lint-refactor"
    }:
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2038,SC2086
        find ${hsDirs} -type f -name "*.hs" | xargs -I % sh -c " \
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
}
