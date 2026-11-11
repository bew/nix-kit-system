{
  description = "kit-system — the nested config module system (kitsys)";

  outputs = { self }: {
    # kitsys takes the caller's `lib` (so option types and priorities come from the
    # consuming module system's nixpkgs) and returns the kitsys attrset with
    # `newKit` / `defineEval`.
    lib.kitsys = import ./kitsys.nix;
  };
}
