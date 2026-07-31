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
    inputs@{
      nixpkgs,
      nix-flatpak,
      llm-agents,
      home-manager,
      vicinae,
      plasma-manager,
      streaming-kit,
      browser-tyan,
      twitch-stream-recoder,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
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
            browser-tyan.nixosModules.default
            {
              nixpkgs.overlays = [
                llm-agents.overlays.shared-nixpkgs
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
                plasma-manager.homeModules.plasma-manager
                nix-flatpak.homeManagerModules.nix-flatpak
                streaming-kit.homeManagerModules.streaming-kit-cli
                streaming-kit.homeManagerModules.streaming-kit-desktop
                streaming-kit.homeManagerModules.streaming-kit-hub
                streaming-kit.homeManagerModules.streaming-kit-voicevox-connector
                streaming-kit.homeManagerModules.streaming-kit-stream-orchestrator
                twitch-stream-recoder.homeModules.default
              ];
            }
          ];
        };
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;
      devShell.${system} = pkgs.mkShell {
        packages = with pkgs; [
          biome
          typescript-language-server
          stylua
          nixd
          nixfmt
          lua-language-server
        ];
      };
      nixosConfigurations = {
        laptop = mkHost { hostname = "laptop"; };
        boxfish = mkHost { hostname = "boxfish"; };
        server = mkHost { hostname = "server"; };
        sandbox = mkHost { hostname = "sandbox"; };
        game = mkHost { hostname = "game"; };
      };
    };
}
