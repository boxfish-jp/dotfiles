import { describe, expect, test } from "bun:test";
import { GitPolicyPlugin } from "../plugins/git_policy.ts";

type Hook = {
  "tool.execute.before"?: (
    input: { tool: string; sessionID: string; callID: string },
    output: { args: Record<string, unknown> },
  ) => Promise<void>;
  event?: (input: {
    event: { type: string; properties?: unknown };
  }) => Promise<void>;
};

type PluginInput = Parameters<typeof GitPolicyPlugin>[0];

const makeHarness = (agent: string) => {
  const replies: {
    id: string;
    sessionID: string;
    permissionID: string;
    response: string;
  }[] = [];
  const client = {
    session: {
      get: async () => ({ data: { agent } }),
    },
    app: { log: async () => undefined },
    postSessionIdPermissionsPermissionId: async (options: {
      path: { id: string; permissionID: string };
      body: { response: string };
    }) => {
      replies.push({
        id: "sent",
        sessionID: options.path.id,
        permissionID: options.path.permissionID,
        response: options.body.response,
      });
    },
  };
  const plugin = GitPolicyPlugin({
    client,
  } as unknown as PluginInput);
  return { replies, hooks: plugin as unknown as Promise<Hook> };
};

const ask = async (agent: string, command: string) => {
  const { replies, hooks } = makeHarness(agent);
  const hook = await hooks;
  await hook.event?.({
    event: {
      type: "permission.asked",
      properties: {
        id: "per_1",
        sessionID: "ses_1",
        permission: "bash",
        patterns: [command],
        metadata: { command },
        always: [],
      },
    },
  });
  return replies;
};

const before = async (agent: string, command: string) => {
  const { hooks } = makeHarness(agent);
  const hook = await hooks;
  await hook["tool.execute.before"]?.(
    { tool: "bash", sessionID: "ses_1", callID: "call_1" },
    { args: { command } },
  );
};

describe("GitPolicyPlugin", () => {
  describe("permission.askedイベントへの自動返信", () => {
    test("読み取り専用gitコマンドにはonceで自動承認する", async () => {
      const replies = await ask("plan", "git -C /tmp/x log --oneline -5");
      expect(replies).toHaveLength(1);
      expect(replies[0].response).toBe("once");
    });

    test("buildモードではgit addも自動承認する", async () => {
      const replies = await ask("build", "git add .");
      expect(replies).toHaveLength(1);
    });

    test("planモードではgit addを自動承認しない", async () => {
      const replies = await ask("plan", "git add .");
      expect(replies).toHaveLength(0);
    });

    test("gitを含まないコマンドには返信しない", async () => {
      const replies = await ask("build", "rm -rf /tmp/x");
      expect(replies).toHaveLength(0);
    });

    test("パイプ先が非gitのコマンドには返信しない", async () => {
      const replies = await ask("build", "git log | head -5");
      expect(replies).toHaveLength(0);
    });

    test("bash以外の権限要求には返信しない", async () => {
      const { replies, hooks } = makeHarness("build");
      const hook = await hooks;
      await hook.event?.({
        event: {
          type: "permission.asked",
          properties: {
            id: "per_1",
            sessionID: "ses_1",
            permission: "edit",
            patterns: ["todo.org"],
            metadata: { filepath: "todo.org" },
            always: [],
          },
        },
      });
      expect(replies).toHaveLength(0);
    });

    test("permission.asked以外のイベントには反応しない", async () => {
      const { replies, hooks } = makeHarness("build");
      const hook = await hooks;
      await hook.event?.({
        event: { type: "session.idle", properties: {} },
      });
      expect(replies).toHaveLength(0);
    });
  });

  describe("tool.execute.beforeによる拒否", () => {
    test("-C付きのgit commitを拒否する", async () => {
      await expect(before("build", "git -C repo commit -m m")).rejects.toThrow(
        /commit/,
      );
    });

    test("buildモードのgit addは拒否しない", async () => {
      await expect(before("build", "git add .")).resolves.toBeUndefined();
    });

    test("planモードのgit addは拒否する", async () => {
      await expect(before("plan", "git add .")).rejects.toThrow(/add/);
    });

    test("git pullを拒否する", async () => {
      await expect(before("build", "git pull")).rejects.toThrow(/pull/);
    });

    test("読み取り専用gitは拒否しない", async () => {
      await expect(before("plan", "git status")).resolves.toBeUndefined();
    });

    test("非gitコマンドは拒否しない", async () => {
      await expect(before("plan", "rm -rf /tmp/x")).resolves.toBeUndefined();
    });
  });
});
