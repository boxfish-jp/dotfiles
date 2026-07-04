{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs = {
    streaming-kit-cli = {
      enable = true;

      workDir = "~/dev/";
      serverUrl = "http://192.168.68.16:8888";

      systemd.enable = true;
      systemd.serviceName = "streaming-kit-cli";
    };

    streaming-kit-desktop = {
      enable = true;

      systemd.enable = true;
      systemd.serviceName = "streaming-kit-desktop";
    };
  };
}
