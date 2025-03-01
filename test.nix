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

        modules = args.modules ++ [
          # This module is injected here since it exposes the nixpkgs self-path in as
          # constrained of contexts as possible to avoid more things depending on it and
          # introducing unnecessary potential fragility to changes in flakes itself.
          #
          # See: failed attempt to make pkgs.path not copy when using flakes:
          # https://github.com/NixOS/nixpkgs/pull/153594#issuecomment-1023287913
          ({ config, pkgs, lib, ... }: {
            config.nixpkgs.flake.source = self.outPath;
          })
        ];
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
        builtins.toJSON val;

  nixos = (lib.traceVal nixosLib).evalModules {
    modules = [
      {nixpkgs.hostPlatform = { system = "aarch64-linux"; };}
    ];
  };

  result = toJSONLossy nixos.config;
in assert result; null
