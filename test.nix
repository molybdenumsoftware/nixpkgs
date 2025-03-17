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
  # [x] Explicit throws
  # [x] assertions
  # [x] out of bounds
  # [x] missing attr
  # [ ] infinite recursion (detects cycle by thunk  "black hole")
  # [ ] stack overflow (arbitrary depth limit) (possibly configurable?)

  catchEvalDeep =
    path: maybe:
    let
      result = builtins.catchEvalErrors maybe;
      val = if result.success then result.value else "«error»";
    in
    if builtins.length path > 6 then "«infrec»" else
    (lib.trace (lib.concatStrings path)
      (
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
          # let
          #   result = builtins.tryEval val.drvPath;
          # in
          #   if result.success then
          #     "«derivation ${val.drvPath}»"
          #   else
          #     "«error: failed to evaluate derivation»"
          else if hasType && val ? drvPath then
            "«what is this undocumented derivationStrict?»"
          else if val.__attrsFailEvaluation or false then
            "«attrset with __attrsFailEvaluation»"
          else
            lib.mapAttrs (name: value: catchEvalDeep (path ++ [ ".${name}" ]) value) val
        else if lib.isList val then
          lib.imap0 (i: v: catchEvalDeep (path ++ [ "[${toString i}]" ]) v) val
        else
          val
      ));
  # __attrsFailEvaluation

  nixos = nixosSystem {
    modules = [
      { nixpkgs.hostPlatform = { system = "aarch64-linux"; }; }
    ];
  };

  final = lib.pipe nixos.config [
    (catchEvalDeep [])
    builtins.toJSON
  ]
    ;
in
assert final; null
