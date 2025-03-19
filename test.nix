let
  lib = import ./lib;

  nixosSystem =
    args:
    import ./nixos/lib/eval-config.nix (
      {
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

  display =
    val:
    if lib.isPath val then
      "«path ${toString val}»"
    else if lib.isFunction val then
      "«function»"
    else if lib.isDerivation val then
      let
        #result = builtins.catchEvalErrors val.drvPath; TODO
        result = {
          success = false;
        };
      in
      "«derivation ${if result.success then result.value else "evaluation error"}»"
    else
      val;

  omit =
    path: x:
    if
      lib.any lib.id [
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

  catchAndDisplayRecursive =
    x:
    lib.flip lib.pipe [
      (lib.trivial.mapRecursiveTopDown (
        _: x:
        let
          result = builtins.catchEvalErrors x;
        in
        if result.success then result.value else "«evaluation error»"
      ))
      (lib.trivial.mapRecursiveTopDown omit)
      (lib.trivial.mapRecursiveTopDown (_: display))
    ];

in
catchAndDisplayRecursive testValue
