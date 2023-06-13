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
      hsDirs = "src";

      mkShell =
        nix-hs-utils.mkHaskellPkg {
          inherit compiler pkgs;
          name = "example";
          root = ./.;
          returnShellEnv = true;
        };
    in
    {
      devShells."${system}".default = mkShell;

      apps."${system}" = {
        format = nix-hs-utils.format {
          inherit compiler hsDirs pkgs;
        };
        format-fourmolu = nix-hs-utils.format {
          inherit compiler hsDirs pkgs;
          hsFmt = "fourmolu";
        };
        lint = nix-hs-utils.lint {
          inherit compiler hsDirs pkgs;
        };
        lint-refactor = nix-hs-utils.lint-refactor {
          inherit compiler hsDirs pkgs;
        };
      };
    };
}
