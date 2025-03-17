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

  # EvalError
  # Explicit throws
  # assertions
  # out of bounds
  # missing attr
  # infinite recursion (detects cycle by thunk  "black hole")
  # stack overflow (arbitrary depth limit) (possibly configurable?)

  toJSONLossy =
    path: maybe:
    let
      result = builtins.catchEvalErrors maybe;
      val = if result.success then result.value else "«error»";
    in
    if builtins.length path > 10 then "«infrec»" else
    (lib.trace (lib.concatStrings path)
      (
        if lib.isFunction val then
          "«function»"
        else if lib.isAttrs val then
          let
            hasType = val ? type && (builtins.catchEvalErrors val.type).success;
          in
          if hasType && lib.isDerivation val then
            "«derivation»"
          # let
          #   result = builtins.tryEval val.drvPath;
          # in
          #   if result.success then
          #     "«derivation ${val.drvPath}»"
          #   else
          #     "«error: failed to evaluate derivation»"
          else if hasType && val ? drvPath then
            "«what is this undocumented derivationStrict?»"
          else
            lib.pipe val [
              (lib.flip lib.removeAttrs [ "assertions" ])
              (lib.mapAttrs (name: value: toJSONLossy (path ++ [ ".${name}" ]) value))
              builtins.toJSON
            ]
        else if lib.isList val then
          lib.imap0 (i: v: toJSONLossy (path ++ [ "[${toString i}]" ]) v) val
        else
          builtins.toJSON val
      ));

  nixos = nixosSystem {
    modules = [
      { nixpkgs.hostPlatform = { system = "aarch64-linux"; }; }
    ];
  };

  final = toJSONLossy [ ] nixos.config;
in
assert final; null
