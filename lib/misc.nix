let
  utils = import ./utils.nix;

  /*
    Makes a library from source.

    Example:
      inputs.some-hs-lib.url = "github:user/some-hs-lib";
      compiler = pkgs.haskell.packages."${ghc-version}".override {
        overrides = final: prev: {
          some-hs-lib = nix-hs-utils.mkLib inputs final "some-hs-lib";
        }
      };

    Type: mkLib :: AttrSet -> AttrSet -> String -> Derivation
  */
  mkLib =
    inputs: p: lib:
    p.callCabal2nix lib inputs."${lib}" { };

  /*
    Makes a library from a relative source.

    Example:
      # i.e. path is some-hs-libs/sub-dir-lib
      inputs.some-hs-libs.url = "github:user/some-hs-libs";
      compiler = pkgs.haskell.packages."${ghc-version}".override {
        overrides = final: prev: {
          sub-dir-lib = nix-hs-utils.mkRelLib some-hs-libs final "sub-dir-lib"
        }
      };

    Type: mkRelLib :: AttrSet -> AttrSet -> String -> Derivation
  */
  mkRelLib =
    rel: p: lib:
    p.callCabal2nix lib "${rel}/${lib}" { };

  # Cabal GHC, and zlib
  mkBuildTools =
    { pkgs, compiler }:
    [
      compiler.cabal-install
      compiler.ghc
      pkgs.zlib
    ];

  # Formatters (cabal-fmt, nix formatter, ormolu/fourmolu)
  # Linter (HLint + refactor)
  # HLS
  mkDevTools =
    {
      pkgs,
      compiler,
      nixFmt ? "nixfmt",
    }:
    let
      hlib = pkgs.haskell.lib;
      nixFmt' = utils.getNixFmt nixFmt;
    in
    [
      (hlib.dontCheck compiler.apply-refact)
      (hlib.dontCheck compiler.cabal-fmt)
      # NOTE: We don't need to explicitly include ormolu/fourmolu because
      # HLS includes both CLI tools
      (hlib.dontCheck compiler.haskell-language-server)
      (hlib.dontCheck compiler.hlint)
      (nixFmt'.dep pkgs)
    ];
in
{
  inherit
    mkLib
    mkRelLib
    mkBuildTools
    mkDevTools
    ;

  /*
    Turns a list of libs into an attr set via mkLib.

    Example:
      inputs.some-hs-lib1.url = "github:user/some-hs-lib1";
      inputs.some-hs-lib2.url = "github:user/some-hs-lib2";
      compiler = pkgs.haskell.packages."${ghc-version}".override {
        overrides = final: prev: {
          ...
        } // nix-hs-utils.mkLibs inputs final [
          "some-hs-lib1"
          "some-hs-lib2"
        ];
     };

    Type: mkLibs :: AttrSet -> AttrSet -> List String -> Derivation
  */
  mkLibs =
    inputs: p: libs:
    builtins.foldl' (acc: name: acc // { ${name} = mkLib inputs p name; }) { } libs;

  /*
    Turns a list of relative libs into an attr set via mkRelLib.

     Example:
       # i.e. paths are some-hs-libs/sub-dir-lib1 and some-hs-libs/sub-dir-lib2
       inputs.some-hs-libs.url = "github:user/some-hs-libs";
       compiler = pkgs.haskell.packages."${ghc-version}".override {
         overrides = final: prev: {
           ...
         } // nix-hs-utils.mkRelLibs some-hs-libs final [
           "sub-dir-lib1"
           "sub-dir-lib2"
         ];
       };

    Type: mkRelLibs :: AttrSet -> AttrSet -> List String -> Derivation
  */
  mkRelLibs =
    rel: p: libs:
    builtins.foldl' (acc: x: acc // { ${x} = mkRelLib rel p x; }) { } libs;

  /*
    Derivation for a haskell package via developPackage. The following
     fields are mandatory:

     - name (String):
         Haskell package name.

     - compiler:
         The haskell compiler to use.

     - pkgs: Nixpkgs.

     - returnShellEnv (Boolean):
         If true, returns a shell suitable for 'nix develop'. Otherwise returns
         a derivation.

     - root (Path):
         The root directory (i.e. directory with the cabal file).

     The following fields are optional:

     - baseModifier (Boolean):
         If true (default), we start by adding build tools per mkBuildTools
         and, if returnShellEnv is true, dev tools per devTools.

     - devTools (List):
         If null (default), uses mkDevTools. Note this field is only used if
         baseModifier and returnShellEnv are true.

     - modifier (Derivation -> Derivation):
         Applies the modifier on top of the base modifier. Defaults to the
         identity function.

    - nixFmt (String):
         Selects which nix formatter to provide as part of the default (null)
         devTools. Defaults to "nixfmt". Can also be "nixpkgs-fmt".

     Example:
      let
        pkgs = import nixpkgs { inherit system; };
        compiler = pkgs.haskell.packages.ghc945;
      in mkHaskellPkg
        { inherit compiler pkgs;
          name = "my-haskell-pkg";
          returnShellEnv = true;
          root = ./.;
          devTools = [ compiler.haskell-language-server ]
          modifier = drv: addTestToolDepend pkgs.git drv
        };

     Type: mkHaskellPkg :: AttrSet -> Derivation
  */
  mkHaskellPkg =
    {
      name,
      compiler,
      pkgs,
      returnShellEnv,
      root,
      baseModifier ? true,
      devTools ? null,
      modifier ? utils.id,
      nixFmt ? "nixfmt",
      source-overrides ? {},
    }:
    let
      pkgsCompiler = {
        inherit pkgs compiler;
      };
      devTools' = if devTools == null then mkDevTools (pkgsCompiler // { inherit nixFmt; }) else devTools;
      baseModifier' =
        if baseModifier then
          drv:
          pkgs.haskell.lib.addBuildTools drv (
            mkBuildTools pkgsCompiler ++ (if returnShellEnv then devTools' else [ ])
          )
        else
          utils.id;
      modifier' = drv: modifier (baseModifier' drv);
    in
    compiler.developPackage {
      inherit name root returnShellEnv source-overrides;
      modifier = modifier';
    };
}
