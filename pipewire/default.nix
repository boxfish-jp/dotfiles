{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  xdg.configFile."pipewire/pipewire.conf.d/99-virtual-cables.conf".text = ''
    context.objects = [
      { factory = adapter
        args = {
          factory.name     = "support.null-audio-sink"
          node.name        = "default-output"
          node.description = "default"
          media.class      = "Audio/Sink"
        }
      }
      { factory = adapter
        args = {
          factory.name     = "support.null-audio-sink"
          node.name        = "for-obs"
          node.description = "obs always listen"
          media.class      = "Audio/Sink"
        }
      }
    ]
  '';
}
