const COMMAND_NOT_FOUND = /(\S+): command not found/;

const PACKAGE_OVERRIDES: Record<string, string> = {
  python: "python3",
  npm: "nodejs",
  npx: "nodejs",
  make: "gnumake",
  cc: "gcc",
  "g++": "gcc",
};

export const findMissingCommand = (output: string): string | null =>
  output.match(COMMAND_NOT_FOUND)?.[1] ?? null;

export const buildNixHint = (command: string): string => {
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
