{
  inputs,
  lib,
  ...
}:
let
  plugins = import ./_plugins.nix { inherit inputs lib; };
  remoteSkills = import ./_remote-skills.nix;
in
{
  perSystem =
    { pkgs, ... }:
    let
      mcpBundle = pkgs.runCommand "dsh-config-mcp" { } ''
        mkdir -p "$out"
        cp ${./config/mcp/package.json} "$out/package.json"
        cp ${./config/mcp/cordis.patch.yml} "$out/cordis.patch.yml"
      '';

      agentsAnywhereBridge = import ./_agents-anywhere.nix { inherit inputs pkgs; };

      remoteSkillSources = lib.mapAttrsToList (
        name: source:
        if !(source ? owner) || !(source ? repo) || !(source ? rev) || !(source ? hash) then
          throw "dsh skills: ${name} に owner/repo/rev/hash が揃っていません。nix run .#dsh-skills-update を実行してください。"
        else
          pkgs.fetchFromGitHub {
            inherit (source)
              owner
              repo
              rev
              hash
              ;
          }
      ) remoteSkills;

      mkDsh =
        profiles:
        inputs.dsh-profile-nix.lib.mkDsh {
          inherit pkgs;
          dsh = inputs.llm-agents.packages.${pkgs.system}.dsh;
          # mkDsh の既定は 8080 だが、dsh の web 既定は 3080 なので合わせる。
          webPort = 3080;
          skills = [ ../skills ] ++ remoteSkillSources;
          plugins = plugins.listFor pkgs ++ [ mcpBundle ];
          inherit profiles;
        };

      # Agents Anywhere は sandbox をスマホから操作するためだけに入れる。
      # ブリッジは `sandbox` プロファイルにだけ載せ、他のホストの閉包には含めない。
      dsh = mkDsh { web = { }; };

      dshAgentsAnywhere = mkDsh {
        web = { };
        sandbox = {
          from = "web";
          plugins = [ agentsAnywhereBridge ];
        };
      };
    in
    {
      packages = plugins.packagesFor pkgs // {
        inherit dsh;
        dsh-agents-anywhere = dshAgentsAnywhere;
      };

      apps.dsh-plugins-update = {
        type = "app";
        program = lib.getExe (plugins.updateScript pkgs);
      };

      apps.dsh-skills-update =
        let
          updateScript = pkgs.writeShellApplication {
            name = "dsh-skills-update";
            runtimeInputs = with pkgs; [
              coreutils
              gawk
              git
              jq
              nix
            ];
            text = builtins.readFile ./update-skills.sh;
          };
        in
        {
          type = "app";
          program = "${updateScript}/bin/dsh-skills-update";
        };
    };

  flake.homeModules.dsh =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      cfg = config.llm.dsh;
    in
    {
      options.llm.dsh.agentsAnywhere.enable =
        lib.mkEnableOption "the Agents Anywhere bridge for phone remote control";

      config = {
        home.packages = [
          (
            if cfg.agentsAnywhere.enable then
              self.packages.${pkgs.system}.dsh-agents-anywhere
            else
              self.packages.${pkgs.system}.dsh
          )
        ];

        # dsh は $DSH_HOME/AGENTS.md を全セッション共通の指示として読む。
        home.file.".dsh/AGENTS.md".source = ./AGENTS.md;
      };
    };
}
