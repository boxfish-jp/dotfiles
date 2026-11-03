{ inputs, ... }:
{
  flake.homeModules.browser-chan = _: {
    imports = [ inputs.browser-chan.homeManagerModules.default ];
  };
}
