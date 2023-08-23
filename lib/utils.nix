let
  showKeys = attrs:
    let attrKeys = builtins.attrNames attrs;
    in builtins.concatStringsSep ", " attrKeys;

  lookupOrDie = mp: key: keyName:
    if mp ? ${key}
    then mp.${key}
    else throw "Invalid ${keyName}: '${key}'; valid keys are ${showKeys mp}.";

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

  findCmd = args:
    if args.fd
    then "fd ${args.findArgs} -e ${args.ext}"
    else "find ${args.findArgs} -type f -name '*${args.ext}'";
in
{
  inherit findCmd;

  id = x: x;

  getHsFmt = hsFmtName: lookupOrDie nameToHsFmt hsFmtName "haskell formatter";
}
