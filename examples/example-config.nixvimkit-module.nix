# The example neovim config, passed to `nixvimkit.eval` as `configModule`.
#
# It declares the kit's demo option itself.
{ lib, ... }:
let
  ty = lib.types;
in {
  options = {
    example.greeting = lib.mkOption {
      description = "A trivial example option, to show where a kit adds its own options.";
      type = ty.str;
      default = "hello from the nixvim kit";
    };
  };

  config = {
    example.greeting = "hi";

    # A builtin colorscheme, so the built neovim is visibly themed without pulling a plugin.
    colorscheme = "habamax";

    # Stock nixvim plugins that change the look at first glance (no command to run).
    plugins = {
      bufferline.enable = true;
      lualine.enable = true;
    };
  };
}
