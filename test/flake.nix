{
  description = "Test flake";

  # nix
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.nix-hs-utils.url = "../";
  outputs =
    {
      nix-hs-utils,
      nixpkgs,
      self,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      ghc-version = "ghc964";
      compiler = pkgs.haskell.packages."${ghc-version}".override { overrides = final: prev: { }; };
      findHsArgs = "src";

      mkShell =
        returnShellEnv:
        nix-hs-utils.mkHaskellPkg {
          inherit compiler pkgs returnShellEnv;
          name = "example";
          root = ./.;
        };

      mkNixFmtShell =
        nixFmt:
        nix-hs-utils.mkHaskellPkg {
          inherit compiler pkgs nixFmt;
          name = "example";
          root = ./.;
          returnShellEnv = true;
        };

      compilerPkgs = {
        inherit compiler pkgs;
      };
      pkgsMkDrv = {
        inherit pkgs;
        mkDrv = false;
      };
    in
    {
      packages."${system}".default = mkShell false;
      devShells."${system}" = {
        default = mkShell true;
        nixpkgs-fmt = mkNixFmtShell "nixpkgs-fmt";
        nixfmt = mkNixFmtShell "nixfmt";
      };

      apps."${system}" = {
        # formatting
        format = nix-hs-utils.format compilerPkgs;
        format-fourmolu = nix-hs-utils.format {
          inherit compiler pkgs;
          hsFmt = "fourmolu";
        };
        format-find = nix-hs-utils.format {
          inherit compiler findHsArgs pkgs;
          fd = false;
        };
        format-hs = nix-hs-utils.format-hs compilerPkgs;

        format-nixpkgs-fmt = nix-hs-utils.format {
          inherit compiler pkgs;
          nixFmt = "nixpkgs-fmt";
        };

        format-nixfmt = nix-hs-utils.format {
          inherit compiler pkgs;
          nixFmt = "nixfmt";
        };

        format-yaml = nix-hs-utils.format-yaml { inherit pkgs; };

        # lint
        lint = nix-hs-utils.lint compilerPkgs;
        lint-find = nix-hs-utils.lint {
          inherit compiler findHsArgs pkgs;
          fd = false;
        };

        # lint-refactor
        lint-refactor = nix-hs-utils.lint-refactor compilerPkgs;
        lint-refactor-find = nix-hs-utils.lint-refactor {
          inherit compiler findHsArgs pkgs;
          fd = false;
        };

        lint-yaml = nix-hs-utils.lint-yaml { inherit pkgs; };

        lint-merged = nix-hs-utils.mergeApps {
          apps = [
            (nix-hs-utils.lint (compilerPkgs // pkgsMkDrv))
            (nix-hs-utils.lint-yaml pkgsMkDrv)
          ];
        };
      };
    };
}
