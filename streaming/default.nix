{ inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
  params = import ./_params.nix;
  workDirShell = lib.replaceStrings [ "~" ] [ "$HOME" ] params.workDir;
in
{
  flake.homeModules.streaming = _: {
    programs = {
      streaming-kit-cli = {
        enable = true;

        inherit (params) workDir serverUrl;

        systemd.enable = true;
        systemd.serviceName = "streaming-kit-cli";
      };

      streaming-kit-desktop = {
        enable = true;

        systemd.enable = true;
        systemd.serviceName = "streaming-kit-desktop";
      };
    };
  };

  perSystem =
    { pkgs, ... }:
    let
      inherit (inputs.streaming-kit.packages.${pkgs.system})
        cli
        desktop
        hub
        voicevox_connector
        stream_orchestrator
        ;
    in
    {
      packages = {
        streaming-kit-cli = pkgs.writeShellScriptBin "streaming-kit-cli" ''
          exec ${lib.getExe' cli "cli"} run "''${WORK_DIR:-${workDirShell}}" "''${SERVER_URL:-${params.serverUrl}}" "$@"
        '';

        streaming-kit-desktop = pkgs.writeShellScriptBin "streaming-kit-desktop" ''
          exec ${lib.getExe' desktop "desktop"} "$@"
        '';

        streaming-kit-hub = pkgs.writeShellScriptBin "streaming-kit-hub" ''
          exec ${lib.getExe' hub "hub"} "$@"
        '';

        streaming-kit-voicevox-connector = pkgs.writeShellScriptBin "streaming-kit-voicevox-connector" ''
          export VOICEVOX_URLS="''${VOICEVOX_URLS:-http://127.0.0.1:50021}"
          exec ${lib.getExe' voicevox_connector "voicevox_connector"} "$@"
        '';

        streaming-kit-stream-orchestrator = pkgs.writeShellScriptBin "streaming-kit-stream-orchestrator" ''
          exec ${lib.getExe' stream_orchestrator "stream_orchestrator"} "''${HUB_URL:-${params.serverUrl}}" "$@"
        '';
      };
    };
}
