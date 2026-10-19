import { describe, expect, test } from "bun:test";
import { ExecPolicyPlugin } from "../plugins/exec_policy.ts";

type PluginInput = Parameters<typeof ExecPolicyPlugin>[0];

type Hooks = {
  config?: (cfg: unknown) => void;
  "tool.execute.before"?: (
    input: { tool: string; sessionID: string; callID: string },
    output: { args: Record<string, unknown> },
  ) => Promise<void>;
};

type SessionRecord = { agent?: string; parentID?: string };

const fakeClient = (sessions: Record<string, SessionRecord>): PluginInput =>
  ({
    client: {
      session: {
        get: async ({ path }: { path: { id: string } }) => ({
          data: sessions[path.id],
        }),
      },
    },
  }) as unknown as PluginInput;

const singleSession = (agent: string): PluginInput =>
  fakeClient({ ses_1: { agent } });

const brokenClient = (): PluginInput =>
  ({
    client: {
      session: {
        get: async () => {
          throw new Error("session not found");
        },
      },
    },
  }) as unknown as PluginInput;

const makeHooks = async (
  cfg?: unknown,
  client: PluginInput = singleSession("plan"),
): Promise<Hooks> => {
  const hooks = (await ExecPolicyPlugin(client)) as Hooks;
  hooks.config?.(cfg ?? {});
  return hooks;
};

const invokeBefore = async (
  hooks: Hooks,
  tool: string,
  command: string,
  sessionID = "ses_1",
): Promise<void> => {
  await hooks["tool.execute.before"]?.(
    { tool, sessionID, callID: "call_1" },
    { args: { command } },
  );
};

const denyConfig = {
  permission: { bash: { "*": "allow", "rm *": "deny", "nix-shell *": "deny" } },
  agent: {},
};

describe("ExecPolicyPlugin", () => {
  describe("tool.execute.beforeによる拒否(plan/explorer系統)", () => {
    test("config未読込でもパス指定コマンドの直接実行を拒否する", async () => {
      const hooks = await makeHooks();
      await expect(invokeBefore(hooks, "bash", "./payload")).rejects.toThrow(
        /パス指定コマンド \.\/payload の直接実行/,
      );
    });

    test("config未読込でもインタプリタ実行を拒否する", async () => {
      const hooks = await makeHooks();
      await expect(
        invokeBefore(hooks, "bash", "python3 evil.py"),
      ).rejects.toThrow(/plan\/explorer/);
    });

    test("configのdeny規則を吸収してラッパー越しrmを拒否する", async () => {
      const hooks = await makeHooks(denyConfig);
      await expect(
        invokeBefore(hooks, "bash", "nohup rm -rf /tmp/x"),
      ).rejects.toThrow(/rm はセキュリティポリシー/);
    });

    test("configのdeny規則を吸収してtimeout越しnix-shellを拒否する", async () => {
      const hooks = await makeHooks(denyConfig);
      await expect(
        invokeBefore(hooks, "bash", `timeout 5 nix-shell -p bun --run 'id'`),
      ).rejects.toThrow(/nix-shell はセキュリティポリシー/);
    });

    test("エージェント参照失敗はplan系統と判定できずbuild扱いで素通しする", async () => {
      const hooks = await makeHooks(undefined, brokenClient());
      await expect(invokeBefore(hooks, "bash", "./payload")).resolves.toBeUndefined();
    });
  });

  describe("build 系統では任意実行ベクタを素通し(jev 判断へ)", () => {
    test("パス指定コマンドの直接実行を拒否しない", async () => {
      const hooks = await makeHooks(denyConfig, singleSession("build"));
      await expect(invokeBefore(hooks, "bash", "./payload")).resolves.toBeUndefined();
    });

    test("インタプリタ実行を拒否しない", async () => {
      const hooks = await makeHooks(denyConfig, singleSession("build"));
      await expect(
        invokeBefore(hooks, "bash", "python3 test_foo.py"),
      ).resolves.toBeUndefined();
    });

    test("find -exec を拒否しない", async () => {
      const hooks = await makeHooks(denyConfig, singleSession("build"));
      await expect(
        invokeBefore(hooks, "bash", `find . -name "*.py" -exec pytest {} ';'`),
      ).resolves.toBeUndefined();
    });

    test("config deny 規則のラッパー越し実行は build でも拒否する", async () => {
      const hooks = await makeHooks(denyConfig, singleSession("build"));
      await expect(
        invokeBefore(hooks, "bash", "nohup rm -rf /tmp/x"),
      ).rejects.toThrow(/rm はセキュリティポリシー/);
    });
  });

  describe("サブエージェントは祖先セッションのモードで判定される", () => {
    test("buildルートのgeneralサブエージェントは任意実行ベクタを素通しする", async () => {
      const hooks = await makeHooks(
        denyConfig,
        fakeClient({
          ses_root: { agent: "build" },
          ses_child: { agent: "general", parentID: "ses_root" },
        }),
      );
      await expect(
        invokeBefore(hooks, "bash", "python3 test_foo.py", "ses_child"),
      ).resolves.toBeUndefined();
    });

    test("planルートのgeneralサブエージェントは任意実行ベクタを拒否する", async () => {
      const hooks = await makeHooks(
        denyConfig,
        fakeClient({
          ses_root: { agent: "plan" },
          ses_child: { agent: "general", parentID: "ses_root" },
        }),
      );
      await expect(
        invokeBefore(hooks, "bash", "./payload", "ses_child"),
      ).rejects.toThrow(/パス指定コマンド/);
    });

    test("explorerエージェントはパス指定コマンドの直接実行を拒否する", async () => {
      const hooks = await makeHooks(denyConfig, singleSession("explorer"));
      await expect(invokeBefore(hooks, "bash", "./payload")).rejects.toThrow(
        /パス指定コマンド/,
      );
    });

    test("buildルート配下でもplanサブエージェントは拒否する", async () => {
      const hooks = await makeHooks(
        denyConfig,
        fakeClient({
          ses_root: { agent: "build" },
          ses_child: { agent: "plan", parentID: "ses_root" },
        }),
      );
      await expect(
        invokeBefore(hooks, "bash", "python3 test_foo.py", "ses_child"),
      ).rejects.toThrow(/plan\/explorer/);
    });

    test("parentID循環では infinite loop せずbuild扱いで素通しする", async () => {
      const hooks = await makeHooks(
        denyConfig,
        fakeClient({
          ses_a: { agent: "general", parentID: "ses_b" },
          ses_b: { agent: "general", parentID: "ses_a" },
        }),
      );
      await expect(
        invokeBefore(hooks, "bash", "./payload", "ses_a"),
      ).resolves.toBeUndefined();
    });

    test("parentIDが最大深さを越えると祖先のplan判定は打ち切りbuild扱いする", async () => {
      const sessions: Record<string, SessionRecord> = {};
      for (let i = 0; i < 20; i++) {
        sessions[`ses_${i}`] =
          i === 19
            ? { agent: "plan" }
            : { agent: "general", parentID: `ses_${i + 1}` };
      }
      const hooks = await makeHooks(denyConfig, fakeClient(sessions));
      await expect(
        invokeBefore(hooks, "bash", "./payload", "ses_0"),
      ).resolves.toBeUndefined();
    });

    test("config deny 規則のラッパー越し実行はサブエージェントでも拒否する", async () => {
      const hooks = await makeHooks(
        denyConfig,
        fakeClient({
          ses_root: { agent: "build" },
          ses_child: { agent: "general", parentID: "ses_root" },
        }),
      );
      await expect(
        invokeBefore(hooks, "bash", "nohup rm -rf /tmp/x", "ses_child"),
      ).rejects.toThrow(/rm はセキュリティポリシー/);
    });
  });

  describe("検査対象外", () => {
    test("拒否規則のないコマンド連鎖は拒否しない", async () => {
      const hooks = await makeHooks(denyConfig);
      await expect(
        invokeBefore(hooks, "bash", "ls -la && echo hi"),
      ).resolves.toBeUndefined();
    });

    test("ホワイトリスト相当の安全なコマンドは拒否しない", async () => {
      const hooks = await makeHooks(denyConfig);
      await expect(invokeBefore(hooks, "bash", "ls -la")).resolves.toBeUndefined();
    });

    test("bash以外のツールは検査しない", async () => {
      const hooks = await makeHooks(denyConfig);
      await expect(invokeBefore(hooks, "edit", "./payload")).resolves.toBeUndefined();
    });

    test("command引数がないbash呼び出しは拒否しない", async () => {
      const hooks = await makeHooks(denyConfig);
      await expect(invokeBefore(hooks, "bash", "")).resolves.toBeUndefined();
    });
  });
});
