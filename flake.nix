{
  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.git-hooks-nix.flakeModule
        ./nix/shells/default.nix
        ./nix/checks/pre-commit.nix
        ./nix/packages/chess2rt.nix
      ];
      systems = import inputs.systems;
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dlang-nix = {
      url = "github:PetarKirov/dlang.nix";
      # Intentionally *not* following our nixpkgs: dlang.nix pre-built
      # binaries (ldc-binary, dmd-binary) link against libxml2.so.2,
      # which the current nixos-unstable libxml2 (2.15+) no longer
      # provides. Tracking upstream at dlang.nix; once resolved we can
      # share a single nixpkgs across the flake.
      inputs.flake-parts.follows = "flake-parts";
    };

    systems.url = "github:nix-systems/triplet";
  };
}
