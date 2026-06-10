{
  config,
  pkgs,
  lib,
  ...
}:{
  services.flatpak = {
    remotes = lib.mkOptionDefault [{
      name = "flathub-beta";
      location = "https://flathub.org/beta-repo/flathub-beta.flatpakrepo";
    }];
    update.auto.enable = true;
    uninstallUnmanaged = true;
    packages = [
      #{ appId = "com.brave.Browser"; origin = "flathub"; }
      #"com.obsproject.Studio"
      #"im.riot.Riot"
      "sh.ppy.osu"
    ];

  };
}
