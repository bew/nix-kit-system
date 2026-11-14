# The example NixOS system's config, passed to `nixoskit.eval` as `configModule`.
#
# It declares the kit's demo option itself, and sets the minimum NixOS needs for a minimal system.
{ lib, ... }:
let
  ty = lib.types;
in {
  options = {
    example.greeting = lib.mkOption {
      description = "A trivial example option, to show where a kit adds its own options.";
      type = ty.str;
      default = "hello from the NixOS kit";
    };
  };

  config = {
    example.greeting = "hi";

    networking.hostName = "example";
    system.stateVersion = "26.11";
    boot.loader.grub.enable = false;
    fileSystems."/".device = "nodev";
    fileSystems."/".fsType = "none";
  };
}
