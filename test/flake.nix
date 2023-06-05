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
      hs-dirs = ".";
    in
    {
      apps."${system}" = {
        format = nix-hs-utils.format {
          inherit compiler hs-dirs pkgs;
        };
        lint = nix-hs-utils.lint {
          inherit compiler hs-dirs pkgs;
        };
        lint-refactor = nix-hs-utils.lint-refactor {
          inherit compiler hs-dirs pkgs;
        };
      };
    };
}
