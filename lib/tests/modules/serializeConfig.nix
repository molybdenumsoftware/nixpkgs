{ lib, ... }: {
  options.result = lib.mkOption {
    type = lib.types.str;
  };
  config.result =
    let
      nixos = lib.nixosSystem {
        modules = [ { nixpkgs.hostPlatform = "aarch64-linux"; } ];
      };

      serialized = nixos.config.nixpkgs.hostPlatform.system;
    in serialized;
}
