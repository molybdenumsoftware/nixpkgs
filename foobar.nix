let
  inherit (import <nixpkgs> { }) lib;
in
let
  nixosSystem =
    args:
    import ./nixos/lib/eval-config.nix (
      {
        inherit lib;
        # Allow system to be set modularly in nixpkgs.system.
        # We set it to null, to remove the "legacy" entrypoint's
        # non-hermetic default.
        system = null;

        modules = args.modules;
      }
      // builtins.removeAttrs args [ "modules" ]
    );

  testValue =
    (nixosSystem {
      modules = [
        { nixpkgs.hostPlatform.system = "aarch64-linux"; }
      ];
    }).config;

  mapRecursive = mapRecursive_ [ ];

  mapRecursive_ =
    path: f: x_:
    let
      x = f path x_;
      type = builtins.typeOf x;
    in
    {
      set = lib.mapAttrs (name: mapRecursive_ (path ++ [ name ]) f) x;
      list = lib.imap0 (index: mapRecursive_ (path ++ [ index ]) f) x;
    }
    .${type} or x;

  displayEvalError =
    x:
    let
      result = (
        # EvalError
        # [x] Explicit throws
        # [x] assertions
        # [x] out of bounds
        # [x] missing attr
        # [ ] infinite recursion (detects cycle by thunk  "black hole")
        # [ ] stack overflow (arbitrary depth limit) (possibly configurable?)
        builtins.catchEvalErrors x
      );
    in
    if result.success then result.value else "«error»";

  display =
    val:
    if lib.isPath val then
      "«path ${toString val}»"
    else if lib.isFunction val then
      "«function»"
    else if lib.isAttrs val then
      let
        result = builtins.catchEvalErrors val.type;
        type = result.value;
      in
      if hasType && lib.isDerivation val then
        "«derivation»"
      else if hasType && val ? drvPath then
        "«what is this undocumented derivationStrict?»"
      else if val.__attrsFailEvaluation or false then
        "«attrset with __attrsFailEvaluation»"
      else
        val
    else
      val;

  omit =
    path: x:
    if
      lib.any (x: x) [
        (
          # TODO
          lib.elem path [
            [
              "virtualisation"
              "vmVariant"
            ]
            [
              "virtualisation"
              "vmVariantWithBootLoader"
            ]
          ]
        )
        (x._type or null == "pkgs")
        (x ? recurseForDerivations)
      ]
    then
      "«omitted»"
    else
      x;
in
mapRecursive (
  path:
  lib.trace path (
    lib.flip lib.pipe [
      displayEvalError
      (omit path)
      display
    ]
  )
) testValue
