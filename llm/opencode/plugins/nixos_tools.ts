import type { Plugin } from "@opencode-ai/plugin";

const COMMAND_NOT_FOUND = /(\S+): command not found/;

const PACKAGE_OVERRIDES: Record<string, string> = {
  python: "python3",
  npm: "nodejs",
  npx: "nodejs",
  make: "gnumake",
  cc: "gcc",
  "g++": "gcc",
};

const buildHint = (command: string): string => {
  const pkg = PACKAGE_OVERRIDES[command] ?? command;
  return [
    "",
    `[nixos-tools] "${command}" はPATHに存在しない。ここはNixOSであり、apt/sudo/pip installでの導入は禁止。`,
    `- 単一ツール実行: nix run nixpkgs#${pkg} -- <args> (nixpkgs#プレフィックス必須。無いと "cannot find flake" で失敗する)`,
    "- 複数ツールが必要なビルド等: nix-shell -p <pkg1> <pkg2> --run '<cmd>'",
    "- nixpkgsパッケージ名例: python3, nodejs(npm同梱), go, cargo, rustc, gcc, gnumake, jq, unzip, wget",
    "- 例: pythonスクリプト実行: nix run nixpkgs#python3 -- script.py / Rustビルド: nix-shell -p cargo rustc --run 'cargo build'",
  ].join("\n");
};

export const NixosToolsPlugin: Plugin = async ({ client }) => {
  const _hinted = new Set<string>();
  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "bash") return;
      const command = output.output.match(COMMAND_NOT_FOUND)?.[1];
      if (!command) return;
      const key = `${input.sessionID}:${command}`;
      if (_hinted.has(key)) return;
      _hinted.add(key);
      output.output += buildHint(command);
      await client.app.log({
        body: {
          service: "NixosToolsPlugin",
          level: "info",
          message: `command not found: ${command}`,
        },
      });
    },
  };
};
