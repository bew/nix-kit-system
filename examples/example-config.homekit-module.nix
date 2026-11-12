# The example home's configuration, passed to `homekit.eval` as `configModule`.
#
# It declares the kit's demo option itself, because this kit keeps no `baseModules` of its own
# (see `homekit.nix`).
{ lib, ... }:
let
  ty = lib.types;
in {
  options = {
    example.greeting = lib.mkOption {
      description = "A trivial example option, to show where a kit adds its own options.";
      type = ty.str;
      default = "hello from the home kit";
    };
  };

  config = {
    example.greeting = "hi";
    home.username = "example";
    home.homeDirectory = "/home/example";
    home.stateVersion = "26.11";
  };
}
