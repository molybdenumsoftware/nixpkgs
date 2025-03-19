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
in
lib.debug.catchAndDisplayRecursive testValue
