{
  inputs.nixlib.url = "github:nix-community/nixpkgs.lib";

  outputs = { self, nixlib }: {
    lib.kitsys = import ./kitsys.nix { kitsysLib = nixlib.lib; };
  };
}
