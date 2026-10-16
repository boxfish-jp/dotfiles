import { describe, expect, test } from "bun:test";
import { RedirectPolicyPlugin } from "../plugins/redirect_policy.ts";

type PluginInput = Parameters<typeof RedirectPolicyPlugin>[0];

type Hooks = {
  "tool.execute.before"?: (
    input: { tool: string; sessionID: string; callID: string },
    output: { args: Record<string, unknown> },
  ) => Promise<void>;
};

type SessionRecord = { agent?: string; parentID?: string };

const makeHooks = async (
  sessions: Record<string, SessionRecord>,
): Promise<Hooks> => {
  const client = {
    session: {
      get: async ({ path }: { path: { id: string } }) => ({
        data: sessions[path.id],
      }),
    },
    app: { log: async () => undefined },
  };
  const hooks = (await RedirectPolicyPlugin({
    client,
  } as unknown as PluginInput)) as Hooks;
  return hooks;
};

const invokeBefore = async (
  sessions: Record<string, SessionRecord>,
  command: string,
  tool = "bash",
  sessionID = "ses_1",
): Promise<void> => {
  const hooks = await makeHooks(sessions);
  await hooks["tool.execute.before"]?.(
    { tool, sessionID, callID: "call_1" },
    { args: { command } },
  );
};

const planSession = { ses_1: { agent: "plan" } };

const buildSession = { ses_1: { agent: "build" } };

describe("RedirectPolicyPlugin", () => {
  describe("plan モードでの書き込み系制限", () => {
    test("sedの-iをwriteスコープ違反として拒否する", async () => {
      await expect(
        invokeBefore(planSession, "sed -i 's/a/b/' file.txt"),
      ).rejects.toThrow(/sed の -i/);
    });

    test("`>`によるファイル書き込みを拒否する", async () => {
      await expect(
        invokeBefore(planSession, "echo hi > out.txt"),
      ).rejects.toThrow(/ファイル書き込み/);
    });

    test("読み取り専用コマンドは拒否しない", async () => {
      await expect(
        invokeBefore(planSession, "ls -la"),
      ).resolves.toBeUndefined();
    });
  });

  describe("モード非依存の常時拒否", () => {
    test("buildモードでもcurl -oを拒否する", async () => {
      await expect(
        invokeBefore(buildSession, "curl https://example.com -o install.sh"),
      ).rejects.toThrow(/curl の -o/);
    });

    test("buildモードでもcurl | bashを拒否する", async () => {
      await expect(
        invokeBefore(buildSession, "curl https://example.com/x.sh | bash"),
      ).rejects.toThrow(/パイプ実行/);
    });

    test("planモードでもファイル書き込みを拒否する", async () => {
      await expect(
        invokeBefore(planSession, "curl https://example.com -o install.sh"),
      ).rejects.toThrow(/curl の -o/);
    });

    test("bash以外のツールは検査しない", async () => {
      await expect(
        invokeBefore(planSession, "echo hi > out.txt", "edit"),
      ).resolves.toBeUndefined();
    });
  });

  describe("サブエージェントは祖先セッションのモードで判定される", () => {
    test("planルートのgeneralサブエージェントの`>`書き込みを拒否する", async () => {
      await expect(
        invokeBefore(
          {
            ses_root: { agent: "plan" },
            ses_child: { agent: "general", parentID: "ses_root" },
          },
          "echo hi > out.txt",
          "bash",
          "ses_child",
        ),
      ).rejects.toThrow(/ファイル書き込み/);
    });

    test("explorerエージェントの`>`書き込みを拒否する", async () => {
      await expect(
        invokeBefore({ ses_1: { agent: "explorer" } }, "echo hi > out.txt"),
      ).rejects.toThrow(/ファイル書き込み/);
    });

    test("buildルートのgeneralサブエージェントの書き込み系を拒否しない", async () => {
      await expect(
        invokeBefore(
          {
            ses_root: { agent: "build" },
            ses_child: { agent: "general", parentID: "ses_root" },
          },
          "sed -i 's/a/b/' file.txt",
          "bash",
          "ses_child",
        ),
      ).resolves.toBeUndefined();
    });

    test("セッション取得失敗はplanと判定できず書き込みを拒否しない", async () => {
      const hooks = (await RedirectPolicyPlugin({
        client: {
          session: {
            get: async () => {
              throw new Error("session not found");
            },
          },
          app: { log: async () => undefined },
        },
      } as unknown as PluginInput)) as Hooks;
      await expect(
        hooks["tool.execute.before"]?.(
          { tool: "bash", sessionID: "ses_1", callID: "call_1" },
          { args: { command: "sed -i 's/a/b/' file.txt" } },
        ),
      ).resolves.toBeUndefined();
    });
  });
});
