{ inputs, self, ... }:
let
  lib = inputs.nixpkgs.lib;
  inherit (lib)
    genAttrs
    mkOption
    nameValuePair
    types
    ;

  mkHost =
    {
      hostname,
      users ? [ hostname ],
    }:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit
          hostname
          users
          self
          ;
      };
      modules = [
        self.nixosModules."host-${hostname}"
        inputs.home-manager.nixosModules.home-manager
        inputs.browser-tyan.nixosModules.default
        {
          nixpkgs.overlays = [
            inputs.llm-agents.overlays.shared-nixpkgs
          ];
        }
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit
              inputs
              hostname
              users
              self
              ;
          };
          home-manager.users = genAttrs users (u: self.homeModules."${hostname}/${u}");
          home-manager.sharedModules = [
            inputs.vicinae.homeManagerModules.default
            inputs.plasma-manager.homeModules.plasma-manager
            inputs.nix-flatpak.homeManagerModules.nix-flatpak
            inputs.streaming-kit.homeManagerModules.streaming-kit-cli
            inputs.streaming-kit.homeManagerModules.streaming-kit-desktop
            inputs.streaming-kit.homeManagerModules.streaming-kit-hub
            inputs.streaming-kit.homeManagerModules.streaming-kit-voicevox-connector
            inputs.streaming-kit.homeManagerModules.streaming-kit-stream-orchestrator
            inputs.twitch-stream-recoder.homeModules.default
          ];
        }
      ];
    };

  mkVmApp = name: test: system: pkgs: {
    type = "app";
    program =
      let
        vm =
          (lib.nixosSystem {
            inherit system;
            specialArgs = {
              hostname = name;
              users = [ "tester" ];
              self = { };
            };
            modules = test.modules ++ [
              "${inputs.nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
              {
                networking.hostName = name;
                users.users.tester = {
                  isNormalUser = true;
                  extraGroups = [ "wheel" ];
                  initialPassword = "test";
                };
                security.sudo.wheelNeedsPassword = false;
                virtualisation = {
                  diskSize = 40960;
                  graphics = true;
                };
                nixpkgs.pkgs = pkgs;
                system.stateVersion = "26.11";
              }
            ];
          }).config.system.build.vm;
      in
      lib.getExe vm;
  };
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  config.systems = [ "x86_64-linux" ];

  options.flake = inputs.flake-parts.lib.mkSubmoduleOptions {
    lib = mkOption {
      type = types.attrsOf types.raw;
      default = { };
      description = "flakes 内部から参照するヘルパ群。";
    };
    homeModules = mkOption {
      type = types.attrsOf types.raw;
      default = { };
      description = "home-manager モジュールのカタログ。各 app モジュールが自己登録する。";
    };
    vmTests = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.modules = mkOption {
            type = with types; listOf raw;
            default = [ ];
            description = "VM 上で起動する NixOS モジュール群。";
          };
        }
      );
      default = { };
      description = "使い捨て QEMU VM として起動するテスト構成。nix run .#vm-<name> で呼べる。";
    };
  };

  config = {
    flake.lib.mkHost = mkHost;

    perSystem =
      { pkgs, system, ... }:
      {
        formatter = pkgs.nixfmt-tree;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            biome
            typescript-language-server
            stylua
            nixd
            nixfmt
            lua-language-server
          ];
        };

        apps = lib.mapAttrs' (
          name: test: nameValuePair "vm-${name}" (mkVmApp name test system pkgs)
        ) self.vmTests;
      };
  };
}
