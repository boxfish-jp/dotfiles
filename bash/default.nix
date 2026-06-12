{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  home.file.".mybashrc".source = ./bashrc;
  programs.bash = {
    enable = true;
    initExtra = ''
      source ~/.profile
      source ~/.mybashrc
    '';
  };
}
