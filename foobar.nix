let inherit (import <nixpkgs> { }) lib; in
let
  mapRecursive = f: x_:
    let
      x = f x_;
      type = builtins.typeOf x;
    in
      {
        set = lib.mapAttrs (_: mapRecursive f) x;
        list = lib.map (mapRecursive f) x;
      }.${type} or x;

  f = x: if (builtins.catchEvalErrors x).success then x else "<<error>>"; # TODO

  safeDisplay = x:
    if builtins.catchEvalErrors (display x).success then # TODO
      display x else "<<error>>";

  display = val:
    if lib.isPath val then
      "«path:${toString val}»"
    else if lib.isFunction val then
      "«function»"
    else if lib.isAttrs val then
      let
        hasType = val ? type && (builtins.catchEvalErrors val.type).success;
      in
      if hasType && lib.isDerivation val then
        "«derivation»"
      else if hasType && val ? drvPath then
        "«what is this undocumented derivationStrict?»"
      #else if val._type or null == "pkgs" then
      #  "«pkgs»"
      else if val.__attrsFailEvaluation or false then
        "«attrset with __attrsFailEvaluation»"
      else
        val
    else val;
in
mapRecursive f {
  a = { aa = { aaa = { }; }; };
  b = [ [ 1 ] [ [ 1 ] ] [ [ [ 1 ] ] ] ];
  e = builtins.elemAt [ ] 1;
}
