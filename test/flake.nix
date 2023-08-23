{
  description = "Test flake";

  # nix
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.nix-hs-utils.url = "../";
  outputs = { nix-hs-utils, nixpkgs, self }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      ghc-version = "ghc945";
      compiler = pkgs.haskell.packages."${ghc-version}".override {
        overrides = final: prev: {
          apply-refact = prev.apply-refact_0_11_0_0;
          ormolu = prev.ormolu_0_5_3_0;
        };
      };
      findHsArgs = "src";

      mkShell = returnShellEnv:
        nix-hs-utils.mkHaskellPkg {
          inherit compiler pkgs returnShellEnv;
          name = "example";
          root = ./.;
        };
    in
    {
      packages."${system}".default = mkShell false;
      devShells."${system}".default = mkShell true;

      apps."${system}" = {
        format = nix-hs-utils.format {
          inherit compiler pkgs;
        };
        format-fourmolu = nix-hs-utils.format {
          inherit compiler pkgs;
          hsFmt = "fourmolu";
        };
        format-find = nix-hs-utils.format {
          inherit compiler findHsArgs pkgs;
          fd = false;
        };
        lint = nix-hs-utils.lint {
          inherit compiler pkgs;
        };
        lint-find = nix-hs-utils.lint {
          inherit compiler findHsArgs pkgs;
          fd = false;
        };
        lint-refactor = nix-hs-utils.lint-refactor {
          inherit compiler pkgs;
        };
        lint-refactor-find = nix-hs-utils.lint-refactor {
          inherit compiler findHsArgs pkgs;
          fd = false;
        };
      };
    };
}
