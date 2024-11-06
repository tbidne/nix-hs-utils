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
  drvOrSet = mkDrv: s: if mkDrv then mkShellApp s else s;

  /*
    Merges a list of attr sets representing shell apps into a single app.

    Fields:

    - apps (List AttrSet):
        NonEmpty list of AttrSet shell apps. Each app requires the 'text'
        and 'runtimeInputs' fields.

    - mkDrv (Boolean):
        If true (default), returns a derivation i.e. the shell app. Otherwise
        returns the merged set.

    - name (String):
        The name to use for the merged app. If null or unspecified, we take
        the name of the __first__ app with a non-null name. At least one name
        is required.

    - pkgs (AttrSet):
        The nixpkgs for creating the shell app. Follows the same semantics
        as name.

    Example:
      a1 = ...
      a2 = ...
      a3 = ...

      app = mergeApps { apps = [a1 a2 a3]; };

    Type: mkLibs ::
            List AttrSet ->
            Boolean ->
            Maybe String ->
            Maybe AttrSet ->
            (AttrSet | Derivation)
  */
  mergeApps =
    {
      apps,
      mkDrv ? true,
      name ? null,
      pkgs ? null,
    }:
    let
      init = {
        inherit name pkgs;
        text = "";
        runtimeInputs = [ ];
      };
      mergeApp = acc: app: {
        # Take the first non-null name we find. Apps are not required to
        # have a name, but we need at least one (or top-level) name.
        name =
          if acc.name != null then
            acc.name
          else if app ? name then
            app.name
          else
            acc.name;

        # Same semantics as name: Take the first non-null or top-level.
        pkgs =
          if acc.pkgs != null then
            acc.pkgs
          else if app ? pkgs then
            app.pkgs
          else
            acc.pkgs;

        text = ''
          ${acc.text}

          ${app.text}
        '';
        runtimeInputs = acc.runtimeInputs ++ app.runtimeInputs;
      };
    in
    drvOrSet mkDrv (builtins.foldl' mergeApp init apps);
in
{
  inherit mkApp mkShellApp mergeApps;

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
