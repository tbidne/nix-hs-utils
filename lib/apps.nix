let
  utils = import ./utils.nix;

  # Convenience function for making an app from a derivation.
  mkApp = drv: {
    type = "app";
    program = "${drv}/bin/${drv.name}";
  };

  # Convenience function for making an app from a writeShellApplication.
  mkShellApp =
    {
      name,
      pkgs,
      text,
      runtimeInputs,
    }:
    mkApp (pkgs.writeShellApplication { inherit name text runtimeInputs; });

  # Returns either a shell app derivation or the set itself.
  drvOrSet = mkDrv: s:
    if mkDrv then mkShellApp s else s;
in
{
  inherit mkApp mkShellApp;

  # ShellApp that formats cabal, nix, and haskell via ormolu (default) or
  # fourmolu.
  format =
    {
      compiler,
      pkgs,
      fd ? true,
      findCabalArgs ? ".",
      findHsArgs ? ".",
      findNixArgs ? ".",
      hsFmt ? "ormolu",
      mkDrv ? true,
      name ? "format",
      nixFmt ? "nixfmt",
    }:
    let
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
      hsFmt' = utils.getHsFmt hsFmt;
      nixArgs = {
        inherit fd;
        findArgs = findNixArgs;
        ext = "nix";
      };
      nixFmt' = utils.getNixFmt nixFmt;
    in
    drvOrSet mkDrv {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2046
        ${nixFmt'.cmd nixArgs}

        # shellcheck disable=SC2034,SC2046
        cabal-fmt --inplace $(${utils.findCmd cabalArgs})

        # shellcheck disable=SC2046
        ${hsFmt'.cmd hsArgs}
      '';
      runtimeInputs = [
        compiler.cabal-fmt
        (hsFmt'.dep compiler)
        (nixFmt'.dep pkgs)
        pkgs.fd
        pkgs.findutils
      ];
    };

  format-hs =
    {
      compiler,
      pkgs,
      fd ? true,
      findHsArgs ? ".",
      hsFmt ? "ormolu",
      mkDrv ? true,
      name ? "format",
    }:
    let
      hsFmt' = utils.getHsFmt hsFmt;
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
    in
    drvOrSet mkDrv {
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

  format-yaml =
    {
      pkgs,
      mkDrv ? true,
      name ? "format-yaml",
      text ? "prettier -w -- **/*yaml",
    }:
    drvOrSet mkDrv {
      inherit pkgs name text;
      runtimeInputs = [ pkgs.nodePackages.prettier ];
    };

  # ShellApp that runs hlint on findHsArgs.
  lint =
    {
      compiler,
      pkgs,
      fd ? true,
      findHsArgs ? ".",
      mkDrv ? true,
      name ? "lint",
    }:
    let
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
    in
    drvOrSet mkDrv {
      inherit name pkgs;
      text = ''
        set -e

        export LANG="C.UTF-8"

        # shellcheck disable=SC2046
        hlint $(${utils.findCmd hsArgs})
      '';
      runtimeInputs = [
        compiler.hlint
        pkgs.fd
        pkgs.findutils
      ];
    };

  # ShellApp that runs hlint + refactor on findHsArgs.
  lint-refactor =
    {
      compiler,
      pkgs,
      fd ? true,
      findHsArgs ? ".",
      mkDrv ? true,
      name ? "lint-refactor",
    }:
    let
      hsArgs = {
        inherit fd;
        findArgs = findHsArgs;
        ext = "hs";
      };
    in
    drvOrSet mkDrv {
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

  lint-yaml =
    {
      pkgs,
      mkDrv ? true,
      name ? "lint-yaml",
      text ? "yamllint .",
    }:
    drvOrSet mkDrv {
      inherit pkgs name text;
      runtimeInputs = [ pkgs.yamllint ];
    };
}
