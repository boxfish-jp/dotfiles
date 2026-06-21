{
  config,
  pkgs,
  lib,
  username,
  hostname,
  ...
}:
let
  gitIdentities = {
    "laptop" = {
      name = "labfish";
      email = "168062620+labFish00@users.noreply.github.com";
    };
    "boxfish" = {
      name = "boxfish_jp";
      email = "79849824+boxfish-jp@users.noreply.github.com";
    };
  };

  currentGit = gitIdentities.${hostname} or gitIdentities."boxfish";
in
{
  home.packages = with pkgs; [
    git
    lazygit
    gh
  ];

  xdg.configFile."git/config".text = ''
    [user]
      name = ${currentGit.name}
      email = ${currentGit.email}
    [init]
      defaultBranch = main
    [core]
      editor = nvim
    [credential "https://github.com"]
      helper = 
      helper = !${lib.getExe pkgs.gh} auth git-credential
  '';
}
