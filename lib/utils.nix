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
      text = hsDirs: "ormolu -m inplace $(find ${hsDirs} -type f -name '*.hs')";
      dep = c: c.ormolu;
    };
    "fourmolu" = {
      text = hsDirs: "fourmolu -m inplace $(find ${hsDirs} -type f -name '*.hs')";
      dep = c: c.fourmolu;
    };
  };

  getHsFmt = hsFmtName: lookupOrDie nameToHsFmt hsFmtName "haskell formatter";
in
{
  id = x: x;

  getHsFmt = hsFmtName: lookupOrDie nameToHsFmt hsFmtName "haskell formatter";
}
