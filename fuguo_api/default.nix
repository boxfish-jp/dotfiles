{ inputs, ... }:
{
  flake.homeModules.fuguo-api = _: {
    imports = [ inputs.fuguo-api.homeManagerModules.default ];
  };
}
