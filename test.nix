let
  lib = import ./lib;

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
      path: maybe:
      let
        result = builtins.tryEval maybe;
        val = if result.success then result.value else "«error»";
      in
      lib.trace path
      (if lib.isDerivation val then
        let
          result = builtins.tryEval val.drvPath;
        in
          if result.success then
            "«derivation ${val.drvPath}»"
          else
            "«error: failed to evaluate derivation»"
      else if lib.isFunction val then
        "«function»"
      else if lib.isAttrs val then
        if val ? drvPath then
          "«what is this undocumented derivationStrict?»"
        else
          lib.pipe val [
            (lib.flip lib.removeAttrs ["assertions"])
            (lib.mapAttrs (name: value: toJSONLossy "${path}.${name}" value))
            builtins.toJSON
          ]
      else if lib.isList val then
        map (toJSONLossy "${path}[?]") val
      else
        builtins.toJSON val);

  nixos = nixosSystem {
    modules = [
      {nixpkgs.hostPlatform = { system = "aarch64-linux"; };}
    ];
  };

  final = toJSONLossy "" nixos.config ;
in assert final; null
