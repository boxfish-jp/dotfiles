{ inputs, ... }:
{
  flake.homeModules.fuguo_api = _: {
    imports = [ inputs.fuguo_api.homeManagerModules.default ];
  };
}
