{
  description = "NixOS configuration with stable and unstable packages";

  inputs = {
    # Main channel (latest packages, unstable)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    llm-agents.url = "github:numtide/llm-agents.nix";

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
      llm-agents,
      home-manager,
      vicinae,
      plasma-manager,
      streaming-kit,
      ...
    }:
    let
      system = "x86_64-linux";
      mkHost =
        {
          hostname,
          username ? hostname,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/${hostname}/configuration.nix
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [
                llm-agents.overlays.default
              ];
            }
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs hostname username;
              };
              home-manager.users.${username} = ./hosts/${hostname}/home.nix;
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
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
      nixosConfigurations = {
        laptop = mkHost { hostname = "laptop"; };
        boxfish = mkHost { hostname = "boxfish"; };
      };
    };
}
