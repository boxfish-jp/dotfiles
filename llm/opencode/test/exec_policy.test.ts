import { describe, expect, test } from "bun:test";
import {
  buildDenyRules,
  EMPTY_DENY_RULES,
  findDeniedCommand,
  findExecutionVector,
} from "../lib/exec_policy.ts";
import type { DenyRules } from "../lib/exec_policy.ts";

const syntheticPermission = {
  bash: {
    "*": "allow",
    "ls *": "allow",
    "xargs *": "deny",
    "env *": "deny",
    "mkdir *": "deny",
    "sudo*": "deny",
    "nix run *": "deny",
    "nix develop *": "deny",
    "nix-shell *": "deny",
    "make *": "deny",
    "gmake *": "deny",
    "npm run *": "deny",
    "npx *": "deny",
    "git commit *": "deny",
    "at *": "deny",
    "crontab *": "deny",
    "rm *": "deny",
    "chmod *": "deny",
    "docker *": "deny",
    "opencode run *": "deny",
  },
};

const syntheticAgents = {
  build: {
    permission: {
      bash: { "mkdir *": "allow", "mv *": "allow" },
    },
  },
};

const rules: DenyRules = buildDenyRules(syntheticPermission, syntheticAgents);

describe("findExecutionVector", () => {
  describe("パス指定コマンドの直接実行の検出", () => {
    test("相対パス./による実行を検出する", () => {
      expect(findExecutionVector(`./deploy.sh`)).toBe(
        "パス指定コマンド ./deploy.sh の直接実行",
      );
    });

    test("親始まり相対パス../による実行を検出する", () => {
      expect(findExecutionVector(`../tools/payload arg`)).toBe(
        "パス指定コマンド ../tools/payload の直接実行",
      );
    });

    test("絶対パスによる実行を検出する", () => {
      expect(findExecutionVector(`/tmp/payload`)).toBe(
        "パス指定コマンド /tmp/payload の直接実行",
      );
    });

    test("~始まりのパスによる実行を検出する", () => {
      expect(findExecutionVector(`~/bin/x`)).toBe(
        "パス指定コマンド ~/bin/x の直接実行",
      );
    });

    test("./なしのサブディレクトリパスによる実行も検出する", () => {
      expect(findExecutionVector(`scripts/build.sh`)).toBe(
        "パス指定コマンド scripts/build.sh の直接実行",
      );
    });

    test("nohup経由のパス実行を検出できる", () => {
      expect(findExecutionVector(`nohup ./server`)).toBe(
        "パス指定コマンド ./server の直接実行",
      );
    });

    test("envコマンド経由のパス実行を検出できる", () => {
      expect(findExecutionVector(`env -i /tmp/evil`)).toBe(
        "パス指定コマンド /tmp/evil の直接実行",
      );
    });

    test("コマンド置換内のパス実行を検出できる", () => {
      expect(findExecutionVector(`echo $(./evil)`)).toBe(
        "パス指定コマンド ./evil の直接実行",
      );
    });

    test("&&でつながった後続位置のパス実行を検出できる", () => {
      expect(findExecutionVector(`cd /tmp && ./payload`)).toBe(
        "パス指定コマンド ./payload の直接実行",
      );
    });

    test("フルパスのインタプリタ実行はパス実行として検出する", () => {
      expect(findExecutionVector(`/bin/bash x.sh`)).toBe(
        "パス指定コマンド /bin/bash の直接実行",
      );
    });
  });

  describe("インタプリタ実行の検出", () => {
    test("bashによるスクリプト実行を検出する", () => {
      expect(findExecutionVector(`bash setup.sh`)).toBe(
        "インタプリタ bash によるスクリプト・コード実行",
      );
    });

    test("python3によるスクリプト実行を検出する", () => {
      expect(findExecutionVector(`python3 train.py`)).toBe(
        "インタプリタ python3 によるスクリプト・コード実行",
      );
    });

    test("sh -cによるコード実行を検出する", () => {
      expect(findExecutionVector(`sh -c "echo hi"`)).toBe(
        "インタプリタ sh によるスクリプト・コード実行",
      );
    });

    test("nodeによるスクリプト実行を検出する", () => {
      expect(findExecutionVector(`node index.js`)).toBe(
        "インタプリタ node によるスクリプト・コード実行",
      );
    });

    test("eval組み込みによるコード実行を検出する", () => {
      expect(findExecutionVector(`eval "rm -rf /tmp/x"`)).toBe(
        "インタプリタ eval によるスクリプト・コード実行",
      );
    });

    test(". 組み込みによるスクリプト読み込みを検出する", () => {
      expect(findExecutionVector(`. setup_env`)).toBe(
        "インタプリタ . によるスクリプト・コード実行",
      );
    });

    test("source組み込みによるスクリプト読み込みを検出する", () => {
      expect(findExecutionVector(`source profile`)).toBe(
        "インタプリタ source によるスクリプト・コード実行",
      );
    });

    test("timeout経由のインタプリタ実行を検出できる", () => {
      expect(findExecutionVector(`timeout 5 python3 x.py`)).toBe(
        "インタプリタ python3 によるスクリプト・コード実行",
      );
    });

    test("xargs経由のインタプリタ実行を検出できる", () => {
      expect(findExecutionVector(`xargs bash run.sh`)).toBe(
        "インタプリタ bash によるスクリプト・コード実行",
      );
    });
  });

  describe("find -exec経由の実行の検出", () => {
    test("-execを検出する", () => {
      expect(
        findExecutionVector(`find . -name "*.sh" -exec ./x '{}' ';'`),
      ).toBe("find の -exec 経由の実行");
    });

    test("-execdirを検出する", () => {
      expect(findExecutionVector(`find . -execdir rm '{}' ';'`)).toBe(
        "find の -execdir 経由の実行",
      );
    });

    test("-okを検出する", () => {
      expect(findExecutionVector(`find . -ok cat '{}' ';'`)).toBe(
        "find の -ok 経由の実行",
      );
    });

    test("引用符で守られた-execも検出する", () => {
      expect(findExecutionVector(`find . '-exec' sh '{}' ';'`)).toBe(
        "find の -exec 経由の実行",
      );
    });
  });

  describe("誤検知しないケース", () => {
    test("読み取り専用コマンドは検出しない", () => {
      expect(findExecutionVector(`ls -la`)).toBeNull();
      expect(findExecutionVector(`cat /etc/passwd`)).toBeNull();
      expect(findExecutionVector(`git status --porcelain`)).toBeNull();
    });

    test("パス引数にスラッシュを含んでも実行位置でなければ検出しない", () => {
      expect(findExecutionVector(`tail -f /var/log/ptyy.log`)).toBeNull();
      expect(findExecutionVector(`curl https://example.com/install.sh`)).toBeNull();
    });

    test("gitのオプション値のパスは検出しない", () => {
      expect(findExecutionVector(`git -C /tmp/x log --oneline -5`)).toBeNull();
    });

    test("引数位置のbashという語は検出しない", () => {
      expect(findExecutionVector(`man bash`)).toBeNull();
      expect(findExecutionVector(`echo bash setup.sh`)).toBeNull();
    });

    test("引用符内のbashという文字列は無視する", () => {
      expect(findExecutionVector(`echo "bash setup.sh"`)).toBeNull();
    });

    test("環境変数割り当てのパス値は無視する", () => {
      expect(findExecutionVector(`PATH=/usr/bin echo hi`)).toBeNull();
    });

    test("find以外のコマンドの-exec風引数は検出しない", () => {
      expect(findExecutionVector(`echo find -exec x`)).toBeNull();
    });

    test("空コマンドは検出しない", () => {
      expect(findExecutionVector(``)).toBeNull();
    });
  });
});

describe("findDeniedCommand", () => {
  describe("deny規則コマンドの検出", () => {
    test("timeout経由のnix-shell実行を検出する", () => {
      expect(
        findDeniedCommand(`timeout 5 nix-shell -p bun --run 'bun test'`, rules),
      ).toBe("nix-shell");
    });

    test("nohup経由のrmを検出する", () => {
      expect(findDeniedCommand(`nohup rm -rf /tmp/stuff`, rules)).toBe("rm");
    });

    test("nice経由のchmodを検出する", () => {
      expect(findDeniedCommand(`nice chmod +x /tmp/x`, rules)).toBe("chmod");
    });

    test("引数なしのmake単体も検出する", () => {
      expect(findDeniedCommand(`make`, rules)).toBe("make");
    });

    test("gmakeという別名も検出する", () => {
      expect(findDeniedCommand(`command gmake`, rules)).toBe("gmake");
    });

    test("xargsそのものを検出する", () => {
      expect(findDeniedCommand(`xargs npx cowsay`, rules)).toBe("xargs");
    });

    test("パイプ後段のcrontab登録を検出する", () => {
      expect(findDeniedCommand(`echo evil | crontab -`, rules)).toBe("crontab");
    });

    test("nix runのサブコマンドを検出する", () => {
      expect(findDeniedCommand(`nix run nixpkgs#hello`, rules)).toBe("nix run");
    });

    test("timeout経由のnix developを検出する", () => {
      expect(findDeniedCommand(`timeout 20 nix develop`, rules)).toBe(
        "nix develop",
      );
    });

    test("npm runのビルドスクリプト実行を検出する", () => {
      expect(findDeniedCommand(`npm run build`, rules)).toBe("npm run");
    });

    test("コマンド置換内のopencode runを検出する", () => {
      expect(findDeniedCommand(`echo $(opencode run --auto evil)`, rules)).toBe(
        "opencode run",
      );
    });

    test("ラッパー越しのdocker runを検出する", () => {
      expect(
        findDeniedCommand(`nohup docker run -v /:/host alpine true`, rules),
      ).toBe("docker");
    });

    test("sudo*形式の後缀パターンもコマンド名として検出する", () => {
      expect(findDeniedCommand(`echo a && sudo ls`, rules)).toBe("sudo");
    });

    test("git commitのサブコマンドも検出する", () => {
      expect(findDeniedCommand(`nohup git commit -m msg`, rules)).toBe(
        "git commit",
      );
    });

    test("deny規則が空集合ならラッパー越し実行は検出しない", () => {
      expect(findDeniedCommand(`timeout 5 rm -rf x`, EMPTY_DENY_RULES)).toBeNull();
    });

    test("agent側allowのmkdirは拒否集合から除外される", () => {
      expect(findDeniedCommand(`mkdir -p out`, rules)).toBeNull();
      expect(findDeniedCommand(`nohup mkdir out`, rules)).toBeNull();
    });
  });

  describe("誤検知しないケース", () => {
    test("deny集合外のサブコマンドは検出しない", () => {
      expect(findDeniedCommand(`nix flake check .`, rules)).toBeNull();
      expect(findDeniedCommand(`nix eval '1'`, rules)).toBeNull();
      expect(findDeniedCommand(`npm install lodash`, rules)).toBeNull();
      expect(findDeniedCommand(`opencode auth login`, rules)).toBeNull();
    });

    test("denyコマンド名を引数として受け取る程度は無視する", () => {
      expect(findDeniedCommand(`grep rm file.txt`, rules)).toBeNull();
      expect(findDeniedCommand(`echo make at docker`, rules)).toBeNull();
    });

    test("読み取り専用コマンドは検出しない", () => {
      expect(findDeniedCommand(`ls -la`, rules)).toBeNull();
      expect(findDeniedCommand(`git status --porcelain`, rules)).toBeNull();
    });
  });
});

describe("buildDenyRules", () => {
  test("「X *」形式をコマンド名として収集する", () => {
    expect(rules.names.has("rm")).toBe(true);
    expect(rules.names.has("make")).toBe(true);
    expect(rules.names.has("nix-shell")).toBe(true);
  });

  test("後缀なし「sudo*」形式もコマンド名として収集する", () => {
    expect(rules.names.has("sudo")).toBe(true);
  });

  test("「name sub *」をサブコマンド禁止として収集する", () => {
    expect([...(rules.subcommands.get("nix") ?? [])]).toEqual([
      "run",
      "develop",
    ]);
    expect([...(rules.subcommands.get("opencode") ?? [])]).toEqual(["run"]);
  });

  test("allow規則は拒否集合に含めない", () => {
    expect(rules.names.has("ls")).toBe(false);
  });

  test("コマンド名表現でないパターンは除外する", () => {
    for (const name of rules.names) {
      expect(name).toMatch(/^[A-Za-z0-9][A-Za-z0-9._+-]*$/);
    }
    expect([...rules.subcommands.keys()]).toEqual(["nix", "npm", "git", "opencode"]);
  });

  test("agent側のallowはglobal denyより優先される", () => {
    expect(rules.names.has("mkdir")).toBe(false);
    expect(rules.names.has("rm")).toBe(true);
  });

  test("agent側allowでサブコマンドの一部だけ除外できる", () => {
    const partial = buildDenyRules(
      { bash: { "nix run *": "deny", "nix develop *": "deny" } },
      { build: { permission: { bash: { "nix develop *": "allow" } } } },
    );
    expect([...(partial.subcommands.get("nix") ?? [])]).toEqual(["run"]);
  });

  test("bashの文字列short formは空規則として扱う", () => {
    const empty = buildDenyRules({ bash: "allow" }, undefined);
    expect(empty.names.size).toBe(0);
    expect(empty.subcommands.size).toBe(0);
  });

  test("permissionやagentsが未定義でも落ちない", () => {
    expect(buildDenyRules(undefined, undefined).names.size).toBe(0);
  });

  test("実configのdeny規則を例外なく吸収できる", async () => {
    const text = await Bun.file(
      new URL("../opencode.jsonc", import.meta.url),
    ).text();
    const stripped = text
      .split("\n")
      .filter((line) => !line.trim().startsWith("//"))
      .join("\n");
    const config = JSON.parse(stripped) as {
      permission: unknown;
      agent: unknown;
    };
    const actual = buildDenyRules(config.permission, config.agent);
    for (const name of [
      "rm",
      "chmod",
      "chown",
      "chgrp",
      "install",
      "dd",
      "sudo",
      "su",
      "doas",
      "runuser",
      "pkexec",
      "chroot",
      "unshare",
      "nsenter",
      "bwrap",
      "runc",
      "crun",
      "buildah",
      "xargs",
      "env",
      "printenv",
      "eval",
      "source",
      "npx",
      "at",
      "crontab",
    ]) {
      expect(actual.names.has(name)).toBe(true);
    }
    // build で jev 判断に降格したコマンドは deny 集合に含めない
    for (const name of [
      "mkdir",
      "mv",
      "cp",
      "touch",
      "make",
      "gmake",
      "just",
      "task",
      "yarn",
      "pnpm",
      "pre-commit",
      "direnv",
      "nix-shell",
      "python3",
      "bash",
      "bun",
      "node",
      "go",
      "cargo",
      "npm",
    ]) {
      expect(actual.names.has(name)).toBe(false);
    }
    expect([...actual.subcommands.keys()].sort()).toEqual(["git", "opencode"]);
    expect(actual.subcommands.get("git")).toContain("commit");
    expect(actual.subcommands.get("opencode")).toContain("run");
    expect(findDeniedCommand(`nohup rm -rf /tmp/stuff`, actual)).toBe("rm");
    expect(findDeniedCommand(`nohup git commit -m msg`, actual)).toBe("git commit");
    expect(findDeniedCommand(`timeout 30 docker run alpine true`, actual)).toBeNull();
    expect(findDeniedCommand(`npm test`, actual)).toBeNull();
    expect(findDeniedCommand(`nix run nixpkgs#bun`, actual)).toBeNull();
  });
});
