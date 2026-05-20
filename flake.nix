{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
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
    streaming-kit-cli = {
      url = "github:boxfish-jp/streamingkit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixgl,
      vicinae,
      plasma-manager,
      streaming-kit-cli,
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      hosts = {
        "laptop" = {
          username = "laptop";
        };
        "boxfish" = {
          username = "boxfish";
        };
      };
      commonModules = [
        ./home.nix
        vicinae.homeManagerModules.default
        plasma-manager.homeManagerModules.plasma-manager
        streaming-kit-cli.homeManagerModules.default
      ];
    in
    {
      homeConfigurations = builtins.mapAttrs (
        hostname: hostConfig:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit nixgl system;
            username = hostConfig.username;
            hostname = hostname;
          };
          modules = commonModules;
        }
      ) hosts;
    };
}
