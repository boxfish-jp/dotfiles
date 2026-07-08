{
  pkgs,
  username,
  ...
}:
with pkgs;
{
  home.packages =
    if username == "boxfish" then
      [
        btop-cuda
      ]
    else
      [
        btop
      ];
}
