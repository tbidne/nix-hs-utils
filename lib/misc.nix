let
  utils = import ./utils.nix;

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
  # inputs.some-hs-lib2.url = "github:user/some-hs-lib2";
  # compiler = pkgs.haskell.packages."${ghc-version}".override {
  #   overrides = final: prev: {
  #     ...
  #   } // nix-hs-utils.mkLibs inputs final [
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

  # Formatters (cabal-fmt, nixpkgs-fmt, ormolu/fourmolu)
  # Linter (HLint + refactor)
  # HLS
  mkDevTools =
    { pkgs
    , compiler
    }:
    let
      hlib = pkgs.haskell.lib;
    in
    [
      (hlib.dontCheck compiler.apply-refact)
      (hlib.dontCheck compiler.cabal-fmt)
      # NOTE: We don't need to explicitly include ormolu/fourmolu because
      # HLS includes both CLI tools
      (hlib.dontCheck compiler.haskell-language-server)
      (hlib.dontCheck compiler.hlint)
      pkgs.nixpkgs-fmt
    ];

  # Makes a haskell package via developPackage. The modifier logic is as
  # follows:
  #
  # If baseModifier is true, then we start by adding buildTools per
  # mkBuildTools and, if returnShellEnv is true, devTools per mkDevTools.
  #
  # If baseModifier is false then there is no "base modification" to the
  # derivation.
  #
  # We apply the parameter modifier on top of baseModifier, which defaults
  # to the identity.
  mkHaskellPkg =
    { name
    , compiler
    , pkgs
    , returnShellEnv
    , root
    , baseModifier ? true
    , modifier ? utils.id
    }:
    let
      devTools = mkDevTools { inherit pkgs compiler; };
      baseModifier' =
        if baseModifier
        then drv:
          pkgs.haskell.lib.addBuildTools drv
            (mkBuildTools pkgs compiler ++
              (if returnShellEnv then devTools else [ ]))
        else utils.id;
      modifier' = drv: modifier (baseModifier' drv);
    in
    compiler.developPackage {
      inherit name root returnShellEnv;
      modifier = modifier';
    };
in
{
  inherit
    mkLib
    mkRelLib
    mkLibs
    mkRelLibs
    mkBuildTools
    mkDevTools
    mkHaskellPkg;
}
