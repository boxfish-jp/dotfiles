{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
{
  home.file.".bashrc".source = ./bashrc;
}
