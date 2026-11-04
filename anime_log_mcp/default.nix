{ inputs, ... }:
{
  flake.homeModules.anime-log-mcp = _: {
    imports = [ inputs.anime-log-mcp.homeManagerModules.default ];
  };
}
