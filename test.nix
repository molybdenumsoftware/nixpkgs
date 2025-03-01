let
  lib = import ./lib;
  nixosLib = import ./nixos/lib { inherit lib; };
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

  toJSONLossy =
      maybe:
      let
        result = builtins.tryEval maybe;
        val = if result.success then result.value else "«error»";
      in
      if lib.isDerivation val then
        "«derivation ${val.drvPath}»"
      else if lib.isFunction val then
        "«function»"
      else if lib.isAttrs val then
        if val ? drvPath then
          "«what is this undocumented derivationStrict?»"
        else
          lib.mapAttrs (name: value: toJSONLossy value) val
      else if lib.isList val then
        map toJSONLossy val
      else
        builtins.toJSON (lib.trace_val val);

  nixos = nixosSystem {
    modules = [
      {nixpkgs.hostPlatform = { system = "aarch64-linux"; };}
    ];
  };

  final = toJSONLossy nixos.config;
in assert final; null
