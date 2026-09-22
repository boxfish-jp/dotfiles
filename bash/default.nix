{ self, ... }:
{
  flake.homeModules.bash =
    {
      config,
      pkgs,
      lib,
      hostname,
      ...
    }:
    {
      home.file.".mybashrc".source = ./bashrc;

      home.packages = with pkgs; [
        starship
      ];

      programs.bash = {
        enable = true;
        initExtra = ''
          source ~/.profile
          source ~/.mybashrc
        '';
      };
    }

  ;
}
