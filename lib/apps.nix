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
    , pkgs
    , fd ? true
    , findCabalArgs ? "."
    , findHsArgs ? "."
    , findNixArgs ? "."
    , hsFmt ? "ormolu"
    , name ? "format"
    }:
    let
      hsFmt' = utils.getHsFmt hsFmt;
      cabalArgs = {
        inherit fd;
        findArgs = findCabalArgs;
        ext = "cabal";
      };
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
      nixArgs = {
        inherit fd;
        findArgs = findNixArgs;
        ext = "nix";
      };
    in
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2046
        ${pkgs.nixfmt}/bin/nixfmt $(${utils.findCmd nixArgs})

        # shellcheck disable=SC2034,SC2046
        ${compiler.cabal-fmt}/bin/cabal-fmt --inplace $(${utils.findCmd cabalArgs})

        # shellcheck disable=SC2046
        ${hsFmt'.cmd hsArgs}
      '';
      runtimeInputs = [
        compiler.cabal-fmt
        (hsFmt'.dep compiler)
        pkgs.fd
        pkgs.findutils
        pkgs.nixfmt
      ];
    };

  formatHs =
    { compiler
    , pkgs
    , fd ? true
    , findHsArgs ? "."
    , hsFmt ? "ormolu"
    , name ? "format"
    }:
    let
      hsFmt' = utils.getHsFmt hsFmt;
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
    in
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2046
        ${hsFmt'.cmd hsArgs}
      '';
      runtimeInputs = [
        (hsFmt'.dep compiler)
        pkgs.fd
        pkgs.findutils
      ];
    };

  # ShellApp that runs hlint on findHsArgs.
  lint =
    { compiler
    , pkgs
    , fd ? true
    , findHsArgs ? "."
    , name ? "lint"
    }:
    let
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
    in
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2046
        hlint $(${utils.findCmd hsArgs})
      '';
      runtimeInputs = [ compiler.hlint pkgs.fd pkgs.findutils ];
    };

  # ShellApp that runs hlint + refactor on findHsArgs.
  lintRefactor =
    { compiler
    , pkgs
    , fd ? true
    , findHsArgs ? "."
    , name ? "lintRefactor"
    }:
    let
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
    in
    mkShellApp {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2038
        ${utils.findCmd hsArgs} | xargs -I % sh -c " \
          hlint \
          --ignore-glob=dist-newstyle \
          --ignore-glob=stack-work \
          --refactor \
          --with-refactor=refactor \
          --refactor-options=-i \
          %"
      '';
      runtimeInputs = [
        compiler.apply-refact
        compiler.hlint
        pkgs.fd
        pkgs.findutils
      ];
    };
}
