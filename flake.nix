{
  description = "NixOS configuration with stable and unstable packages";

  nixConfig = {
    extra-substituters = [
      "https://vicinae.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];

  };

  inputs = {
    # Main channel (latest packages, unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    llm-agents.url = "github:numtide/llm-agents.nix";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vicinae = {
      url = "github:vicinaehq/vicinae";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    vicinae-extensions = {
      url = "github:vicinaehq/extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    streaming-kit = {
      url = "github:boxfish-jp/streamingkit";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
    browser-tyan.url = "github:boxfish-jp/browser_tyan";
    twitch-stream-recoder.url = "github:boxfish-jp/twitch-stream-recorder";
  };

  outputs =
    inputs:
    let
      inherit (inputs.nixpkgs.lib) hasPrefix;
      inherit (inputs.nixpkgs.lib.fileset) fileFilter toList;

      isFlakeModule = file: file.hasExt "nix" && file.name != "flake.nix" && !hasPrefix "_" file.name;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = toList (fileFilter isFlakeModule ./.);
    };
}
