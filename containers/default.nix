{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    podman-compose
  ];

  xdg.configFile."containers/policy.json".text = ''
    {
      "default": [
        {
          "type": "insecureAcceptAnything"
        }
      ],
      "transports": {
        "docker-daemon": {
          "": [
            {
              "type": "insecureAcceptAnything"
            }
          ]
        }
      }
    }
  '';
}
