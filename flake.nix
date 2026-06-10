{
  description = "NixOS configuration with stable and unstable packages";

  inputs = {
    # Main channel (latest packages, unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vicinae = {
      url = "github:vicinaehq/vicinae";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    streaming-kit = {
      url = "github:boxfish-jp/streamingkit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-flatpak,
      home-manager,
      vicinae,
      plasma-manager,
      streaming-kit,
      ...
    }:
    let
      system = "x86_64-linux";
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
      nixosConfigurations = {
        boxfish = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./configuration.nix
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs;
                username = "boxfish";
                hostname = "boxfish";
              };
              home-manager.users.boxfish = ./home.nix;
              home-manager.sharedModules = [
                vicinae.homeManagerModules.default
                plasma-manager.homeManagerModules.plasma-manager
                nix-flatpak.homeManagerModules.nix-flatpak
                streaming-kit.homeManagerModules.streaming-kit-cli
                streaming-kit.homeManagerModules.streaming-kit-desktop
              ];
            }
          ];
        };
      };
    };
}
