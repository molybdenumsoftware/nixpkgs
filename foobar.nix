let inherit (import <nixpkgs> { }) lib; in
let
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

  mapRecursive = mapRecursive_ [ ];

  mapRecursive_ = path: f: x_:
    let
      x = f path x_;
      type = builtins.typeOf x;
    in
      {
        set = lib.mapAttrs (name: mapRecursive_ (path ++ [ name ]) f) x;
        list = lib.imap0 (index: mapRecursive_ (path ++ [ index ]) f) x;
      }.${type} or x;

  safe = e: x: if (builtins.catchEvalErrors x).success then x else e;

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
      else if val.__attrsFailEvaluation or false then
        "«attrset with __attrsFailEvaluation»"
      else
        val
    else val;

  omit = path: x:
    if lib.any (x: x)
      [
        (
          # TODO
          lib.elem path [
            [ "virtualisation" "vmVariant" ]
            [ "virtualisation" "vmVariantWithBootLoader" ]
          ]
        )
        (x._type or null == "pkgs")
        (x ? recurseForDerivations)
      ] then "«omitted»" else x;

  safeConfig =
    mapRecursive (path: lib.flip lib.pipe [ (safe "[1;31m«error»[m") (omit path) ]);

  main =
    mapRecursive
      (path: lib.trace path (lib.flip lib.pipe
        [
          displayEvalError
          (omit path)
          display
        ]
      ))
      testValue.config;
in
{
  inherit safeConfig main;
}
