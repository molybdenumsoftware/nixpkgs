let
  inherit (import <nixpkgs> { }) lib;

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
    in
    {
      set = lib.mapAttrs (name: mapRecursive_ (path ++ [ name ]) f) x;
      list = lib.imap0 (index: mapRecursive_ (path ++ [ index ]) f) x;
    }
    .${builtins.typeOf x} or x;

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
    else if lib.isDerivation val then
      let
        result = builtins.catchEvalErrors val.drvPath;
      in
      "«derivation ${if result.success then result.value else ""}»"
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
