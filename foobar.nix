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

  displayEvalError = x: if (builtins.catchEvalErrors x).success then x else "<<error>>"; # TODO
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

  nixosSystem = args:
    import ./nixos/lib/eval-config.nix (
      {
        inherit lib;
        # Allow system to be set modularly in nixpkgs.system.
        # We set it to null, to remove the "legacy" entrypoint's
        # non-hermetic default.
        system = null;

        modules = args.modules;
      } // builtins.removeAttrs args [ "modules" ]
    );

  testValue = nixosSystem {
    modules = [
      { nixpkgs.hostPlatform.system = "aarch64-linux"; }
    ];
  };
in
mapRecursive (lib.flip lib.pipe [displayEvalError display]) testValue
