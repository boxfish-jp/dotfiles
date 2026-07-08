{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    fzf
    ripgrep
    fd
    wl-clipboard
    ffmpeg
    yt-dlp
    ncdu
  ];
}
