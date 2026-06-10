{
  config,
  pkgs,
  lib,
  ...
}:{
  systemd.user.services.qpwgraph = {
      Unit = {
        Description = "PipeWire Graph Qt GUI (qpwgraph)";
        After = [
          "graphical-session.target"
          "pipewire.service"
        ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.qpwgraph}/bin/qpwgraph -m";
        Environment = [
          "WAYLAND_DISPLAY=wayland-0"
          "XDG_RUNTIME_DIR=%t"
        ];
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
  };
}
