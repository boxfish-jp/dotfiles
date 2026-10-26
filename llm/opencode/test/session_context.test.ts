import { describe, expect, test } from "bun:test";
import { chmodSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  collectCommandFacts,
  fetchLatestUserMessage,
} from "../lib/session_context.ts";

type PluginInput = import("@opencode-ai/plugin").PluginInput;

const withTempDir = (helpers: (dir: string) => void): string => {
  const dir = mkdtempSync(`${tmpdir()}/jev-facts-`);
  helpers(dir);
  return dir;
};

const writeScript = (dir: string, name: string, content: string): string => {
  const path = join(dir, name);
  writeFileSync(path, content);
  return path;
};

describe("collectCommandFacts", () => {
  describe("facts", () => {
    test("cwd事実は原則最初に載る", () => {
      const { facts } = collectCommandFacts("ls", "/home/u/proj");
      expect(facts[0]).toBe("cwd (ワークスペース): /home/u/proj");
    });

    test("directory不明はunknownを載せる", () => {
      const { facts } = collectCommandFacts("ls");
      expect(facts[0]).toBe("cwd (ワークスペース): 不明");
      expect(facts[1]).toContain("解析済みセグメント: ls");
    });

    test("解析済みセグメントを演算子付きで列挙する", () => {
      const { facts } = collectCommandFacts("ls -la | grep foo && true");
      expect(
        facts.some(
          (f) =>
            f.includes("ls -la ;; [|] grep foo ;; [&&] true") &&
            f.includes("解析済みセグメント"),
        ),
      ).toBe(true);
    });

    test("存在する被演算子の種別・サイズ・ワークスペース内外を事実化する", () => {
      const dir = withTempDir(() => undefined);
      const file = writeScript(dir, "notes.txt", "abc");
      const { facts } = collectCommandFacts(`ls ${file}`, dir);
      expect(
        facts.some((f) =>
          f.startsWith(`${file}: ファイル, 3 バイト, ワークスペース内`),
        ),
      ).toBe(true);
    });

    test("存在しない被演算子は存在不在として事実化する", () => {
      const { facts } = collectCommandFacts("cat /tmp/no-such-file.txt");
      expect(
        facts.some((f) => f === "/tmp/no-such-file.txt: 判定時点で存在しない"),
      ).toBe(true);
    });

    test("ディレクトリ被演算子はdirectoryとして事実化する", () => {
      const dir = withTempDir(() => undefined);
      const { facts } = collectCommandFacts(`ls ${dir}`, dir);
      expect(facts.some((f) => f.startsWith(`${dir}: ディレクトリ,`))).toBe(
        true,
      );
    });
  });

  describe("インタプリタ引数のスクリプト中身", () => {
    test("bash引数のファイル中身をUNTRUSTEDなスクリプト節に化す", () => {
      const dir = withTempDir(() => undefined);
      const script = writeScript(dir, "setup.sh", "mkdir -p out\ncp a out\n");
      const { facts, scriptSections } = collectCommandFacts(
        `bash ${script}`,
        dir,
      );
      expect(scriptSections).toEqual([
        `--- ${script} ---\nmkdir -p out\ncp a out\n\n--- 終わり ---`,
      ]);
      expect(facts.filter((f) => f.startsWith(`${script}:`))).toHaveLength(0);
    });

    test("相対パスのスクリプトはworkspace基準で読む", () => {
      const dir = withTempDir(() => undefined);
      writeScript(dir, "run.py", "print(1)");
      const { scriptSections } = collectCommandFacts("python3 run.py", dir);
      expect(scriptSections).toEqual([
        `--- run.py ---\nprint(1)\n--- 終わり ---`,
      ]);
    });

    test("python引数もnode引数も一律で読む", () => {
      const dir = withTempDir(() => undefined);
      const py = writeScript(dir, "go.py", "print(2)");
      const js = writeScript(dir, "go.js", "console.log(3)");
      const { scriptSections } = collectCommandFacts(
        `python3 ${py} && node ${js}`,
        dir,
      );
      expect(scriptSections).toHaveLength(2);
      expect(scriptSections[0]).toContain("print(2)");
      expect(scriptSections[1]).toContain("console.log(3)");
    });

    test("存在しないスクリプトは検証不能事実としてfactsに載る", () => {
      const dir = withTempDir(() => undefined);
      const { facts, scriptSections } = collectCommandFacts(
        "bash missing.sh",
        dir,
      );
      expect(scriptSections).toHaveLength(0);
      expect(
        facts.some((f) =>
          f.startsWith(
            "missing.sh: 判定時点で存在しない (このコマンド本文だけでは挙動を検証できない)",
          ),
        ),
      ).toBe(true);
    });

    test("読めないスクリプトは検証不能事実としてfactsに載る", () => {
      const dir = withTempDir(() => undefined);
      const script = writeScript(dir, "locked.sh", "echo hi\n");
      chmodSync(script, 0o000);
      const { facts, scriptSections } = collectCommandFacts(
        `bash ${script}`,
        dir,
      );
      expect(scriptSections).toHaveLength(0);
      expect(
        facts.some((f) =>
          f.startsWith(`${script}: スクリプト位置のコードは判定時点で読めない`),
        ),
      ).toBe(true);
    });

    test("引数として渡すデータファイルは化さない", () => {
      const dir = withTempDir(() => undefined);
      writeScript(dir, "tool.py", "print('tool')");
      const data = writeScript(dir, "entries.json", '"{}"');
      const { scriptSections } = collectCommandFacts(
        `python3 tool.py ${data}`,
        dir,
      );
      expect(scriptSections).toHaveLength(1);
      expect(scriptSections[0]).toContain("tool.py");
      expect(scriptSections[0]).not.toContain("entries.json");
    });
  });

  describe("shebang付き直接実行", () => {
    test("shebang解釈子が規約内なら中身を化す", () => {
      const dir = withTempDir(() => undefined);
      writeScript(dir, "prove.py", "#!/usr/bin/env python3\nprint('x')");
      const { scriptSections } = collectCommandFacts("./prove.py", dir);
      expect(scriptSections).toHaveLength(1);
      expect(scriptSections[0]).toContain("./prove.py");
      expect(scriptSections[0]).toContain("print('x')");
    });

    test("shebangを持たない直接実行は化さず事実だけ残す", () => {
      const dir = withTempDir(() => undefined);
      writeScript(dir, "toolbin", "PK\u0003\u0004junk");
      const { facts, scriptSections } = collectCommandFacts("./toolbin", dir);
      expect(scriptSections).toHaveLength(0);
      expect(facts.some((f) => f.startsWith("./toolbin: ファイル,"))).toBe(
        true,
      );
    });
  });

  describe("化上限", () => {
    test("合計4KBを共有し超過分は省略注記を残す", () => {
      const dir = withTempDir(() => undefined);
      const a = writeScript(dir, "a.sh", "a".repeat(3000));
      const b = writeScript(dir, "b.sh", "b".repeat(3000));
      const { scriptSections } = collectCommandFacts(
        `bash ${a} && bash ${b}`,
        dir,
      );
      expect(scriptSections[0]).not.toContain("先頭");
      expect(scriptSections[1]).toContain(
        `--- ${b} --- (先頭 1096 / 全 3000 文字を表示)`,
      );
      expect(scriptSections[1]).not.toContain("b".repeat(1097));
    });

    test("枠が尽きた以降は省略注記だけを残す", () => {
      const dir = withTempDir(() => undefined);
      const a = writeScript(dir, "a.sh", "a".repeat(4096));
      const b = writeScript(dir, "b.sh", "b".repeat(10));
      const { scriptSections } = collectCommandFacts(
        `bash ${a} && bash ${b}`,
        dir,
      );
      expect(scriptSections[1]).toBe(
        `--- ${b}: 内容省略 (文字数枠を消費済み) ---`,
      );
    });
  });
});

describe("fetchLatestUserMessage", () => {
  type Client = {
    session: {
      messages: (opts: { path: { id: string } }) => Promise<{ data: unknown }>;
    };
  };

  const makeClient = (data: unknown): Client => ({
    session: {
      messages: async () => ({ data }),
    },
  });

  test("最後のユーザーメッセージのtextを返す", async () => {
    const data = [
      { info: { role: "user" }, parts: [{ type: "text", text: "1件目" }] },
      { info: { role: "assistant" }, parts: [{ type: "text", text: "応答" }] },
      { info: { role: "user" }, parts: [{ type: "text", text: "2件目" }] },
    ];
    await expect(
      fetchLatestUserMessage(
        makeClient(data) as unknown as PluginInput["client"],
        "s1",
      ),
    ).resolves.toBe("2件目");
  });

  test("ユーザーメッセージが無ければundefinedを返す", async () => {
    const data = [
      { info: { role: "assistant" }, parts: [{ type: "text", text: "のみ" }] },
    ];
    await expect(
      fetchLatestUserMessage(
        makeClient(data) as unknown as PluginInput["client"],
        "s1",
      ),
    ).resolves.toBeUndefined();
  });

  test("長文は400字で打ち切る", async () => {
    const data = [
      {
        info: { role: "user" },
        parts: [{ type: "text", text: "あ".repeat(500) }],
      },
    ];
    const result = await fetchLatestUserMessage(
      makeClient(data) as unknown as PluginInput["client"],
      "s1",
    );
    expect(result?.startsWith("あ".repeat(400))).toBe(true);
    expect(result).toContain("…(truncated)");
  });

  test("取得失敗はundefinedを返す", async () => {
    const client = {
      session: {
        messages: async () => {
          throw new Error("api down");
        },
      },
    };
    await expect(
      fetchLatestUserMessage(client as unknown as PluginInput["client"], "s1"),
    ).resolves.toBeUndefined();
  });
});
