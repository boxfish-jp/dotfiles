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

const fakeClient = (agent: string): PluginInput =>
  ({
    client: { session: { get: async () => ({ data: { agent } }) } },
  }) as unknown as PluginInput;

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
  client: PluginInput = fakeClient("plan"),
): Promise<Hooks> => {
  const hooks = (await ExecPolicyPlugin(client)) as Hooks;
  hooks.config?.(cfg ?? {});
  return hooks;
};

const invokeBefore = async (
  hooks: Hooks,
  tool: string,
  command: string,
): Promise<void> => {
  await hooks["tool.execute.before"]?.(
    { tool, sessionID: "ses_1", callID: "call_1" },
    { args: { command } },
  );
};

const denyConfig = {
  permission: { bash: { "*": "allow", "rm *": "deny", "nix-shell *": "deny" } },
  agent: {},
};

describe("ExecPolicyPlugin", () => {
  describe("tool.execute.beforeによる拒否(非 build モード)", () => {
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
      ).rejects.toThrow(/build モード以外では/);
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

    test("エージェント参照失敗は build 扱いせずハード拒否する", async () => {
      const hooks = await makeHooks(undefined, brokenClient());
      await expect(invokeBefore(hooks, "bash", "./payload")).rejects.toThrow(
        /パス指定コマンド/,
      );
    });
  });

  describe("build モードでは任意実行ベクタを素通し(jev 判断へ)", () => {
    test("パス指定コマンドの直接実行を拒否しない", async () => {
      const hooks = await makeHooks(denyConfig, fakeClient("build"));
      await expect(invokeBefore(hooks, "bash", "./payload")).resolves.toBeUndefined();
    });

    test("インタプリタ実行を拒否しない", async () => {
      const hooks = await makeHooks(denyConfig, fakeClient("build"));
      await expect(
        invokeBefore(hooks, "bash", "python3 test_foo.py"),
      ).resolves.toBeUndefined();
    });

    test("find -exec を拒否しない", async () => {
      const hooks = await makeHooks(denyConfig, fakeClient("build"));
      await expect(
        invokeBefore(hooks, "bash", `find . -name "*.py" -exec pytest {} ';'`),
      ).resolves.toBeUndefined();
    });

    test("config deny 規則のラッパー越し実行は build でも拒否する", async () => {
      const hooks = await makeHooks(denyConfig, fakeClient("build"));
      await expect(
        invokeBefore(hooks, "bash", "nohup rm -rf /tmp/x"),
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
