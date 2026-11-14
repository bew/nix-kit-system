{
  outputs = { self }: {
    lib.kitsys = import ./kitsys.nix;

    # --- Sample kits!
    # These are not officially supported by anyone but they're here to offer examples 😉
    # They are not Kits directly as I don't want to add inputs to this flake, so you'll have to pass
    # them through before getting a usable kit.

    # A sample kit for Home Manager
    # (https://github.com/nix-community/home-manager)
    sampleKits.homekit = (
      { nixpkgs, home-manager }:
      import ./sampleKits/homekit.nix {
        inherit nixpkgs home-manager;
        kit-system = self;
      }
    );
  };
}
