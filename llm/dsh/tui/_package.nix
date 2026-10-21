{
  lib,
  pkgs,
  base,
}:
let
  version = (builtins.fromJSON (builtins.readFile ./package.json)).version;

  src = pkgs.runCommandLocal "dsh-tui-${version}-src" { } ''
    mkdir -p $out
    tar -xzf ${pkgs.fetchurl {
      url = "https://registry.npmjs.org/@deepseek-harness-tui/dsh-tui/-/dsh-tui-${version}.tgz";
      hash = "sha256-IUSzF9DCWuTSaI8e8sc7wsleEhCFrFl30AQH3NKxM24=";
    }} -C $out --strip-components=1
    install -m 0644 ${./package.json} $out/package.json
    install -m 0644 ${./package-lock.json} $out/package-lock.json
  '';

  # dsh-tui imports @deepseek-ai/* at runtime; a second copy of cordis/schemastery breaks service identity.
  hostPeers = "${base}/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai";

  package = pkgs.buildNpmPackage {
    pname = "dsh-tui";
    inherit version src;

    npmDepsHash = "sha256-VP6h8tQK9m9oe7+z9X1DJajSlNmlBqB/zja1LLTqW1U=";
    dontNpmBuild = true;
    npmInstallFlags = [ "--legacy-peer-deps" ];
    dontNpmPrune = true;

    # The tarball's @dsh-std/* and MathJax vendor packages are not published at these versions.
    postUnpack = ''
      cp -a "$sourceRoot/node_modules" "$TMPDIR/bundled-node_modules"
    '';

    postInstall = ''
      pkg="$out/lib/node_modules/@deepseek-harness-tui/dsh-tui"

      cp -a "$TMPDIR/bundled-node_modules/." "$pkg/node_modules/"

      mkdir -p "$pkg/node_modules/@deepseek-ai"
      for peer in ${hostPeers}/*; do
        ln -s "$peer" "$pkg/node_modules/@deepseek-ai/$(basename "$peer")"
      done
    '';

    meta = {
      description = "Interactive terminal UI for DeepSeek Harness";
      homepage = "https://github.com/ccch1mneyyy/dsh-TUI";
      license = lib.licenses.mit;
    };
  };

  profileManifest = builtins.toJSON {
    name = "dsh-profile-dsh-tui";
    private = true;
    dependencies."@deepseek-harness-tui/dsh-tui" = version;
    dsh.profile.bundles = [
      "@deepseek-ai/dsh-base"
      "@deepseek-harness-tui/dsh-tui"
    ];
  };

  profile = pkgs.runCommand "dsh-profile-dsh-tui-${version}" { } ''
    mkdir -p $out/node_modules/@deepseek-harness-tui
    printf '%s\n' ${lib.escapeShellArg profileManifest} > $out/package.json
    ln -s ${package}/lib/node_modules/@deepseek-harness-tui/dsh-tui \
      $out/node_modules/@deepseek-harness-tui/dsh-tui
    printf 'packages:\n  - .\n\nnodeLinker: hoisted\nautoInstallPeers: false\n' > $out/pnpm-workspace.yaml
    printf '[]\n' > $out/cordis.yml
    printf '# Nix-managed; the dsh wrapper applies the dotfiles plugin overlay.\n[]\n' > $out/cordis.patch.yml
  '';

  provision = pkgs.writeShellScript "dsh-tui-profile-provision" ''
    set -e

    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}:$PATH

    profile_dir="''${DSH_HOME:-$HOME/.dsh}/profiles/dsh-tui"
    package_link="$profile_dir/node_modules/@deepseek-harness-tui/dsh-tui"

    mkdir -p "$(dirname "$package_link")"

    for file in package.json pnpm-workspace.yaml cordis.patch.yml cordis.yml; do
      if [ ! -e "$profile_dir/$file" ]; then
        install -m 0644 "${profile}/$file" "$profile_dir/$file"
      fi
    done

    rm -rf "$package_link"
    ln -s ${package}/lib/node_modules/@deepseek-harness-tui/dsh-tui "$package_link"
  '';

  launcher = pkgs.writeShellScriptBin "dsh-tui" ''
    set -e

    ${provision}
    exec ${package}/bin/dsh-tui "$@"
  '';
in
{
  inherit package profile provision launcher;
}
