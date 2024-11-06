let
  showKeys =
    attrs:
    let
      attrKeys = builtins.attrNames attrs;
    in
    builtins.concatStringsSep ", " attrKeys;

  lookupOrDie =
    mp: key: keyName:
    if mp ? ${key} then
      mp.${key}
    else
      throw "Invalid ${keyName}: '${key}'; valid keys are ${showKeys mp}.";

  nameToHsFmt = {
    "ormolu" = {
      cmd = findArgs: "ormolu -m inplace $(${findCmd findArgs})";
      dep = c: c.ormolu;
    };
    "fourmolu" = {
      cmd = findArgs: "fourmolu -m inplace $(${findCmd findArgs})";
      dep = c: c.fourmolu;
    };
  };

  getHsFmt = hsFmtName: lookupOrDie nameToHsFmt hsFmtName "haskell formatter";

  nameToNixFmt = {
    "nixfmt" = {
      cmd = findArgs: "nixfmt $(${findCmd findArgs})";
      dep = p: p.nixfmt-rfc-style;
    };
    "nixpkgs-fmt" = {
      cmd = findArgs: "nixpkgs-fmt $(${findCmd findArgs})";
      dep = p: p.nixpkgs-fmt;
    };
  };

  getNixFmt = nixFmtName: lookupOrDie nameToNixFmt nixFmtName "nix formatter";

  findCmd =
    args:
    if args.fd then
      "fd ${args.findArgs} -e ${args.ext}"
    else
      "find ${args.findArgs} -type f -name '*${args.ext}'";
in
{
  inherit findCmd getHsFmt getNixFmt;

  id = x: x;
}
