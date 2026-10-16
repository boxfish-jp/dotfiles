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

type SessionRecord = { agent?: string; parentID?: string };

const makeHarness = (sessions: Record<string, SessionRecord>) => {
  const replies: {
    id: string;
    sessionID: string;
    permissionID: string;
    response: string;
  }[] = [];
  const client = {
    session: {
      get: async ({ path }: { path: { id: string } }) => ({
        data: sessions[path.id],
      }),
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

const singleSession = (agent: string) => ({ ses_1: { agent } });

const ask = async (agent: string, command: string) => {
  const { replies, hooks } = makeHarness(singleSession(agent));
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
  const { hooks } = makeHarness(singleSession(agent));
  const hook = await hooks;
  await hook["tool.execute.before"]?.(
    { tool: "bash", sessionID: "ses_1", callID: "call_1" },
    { args: { command } },
  );
};

const askIn = async (
  sessions: Record<string, SessionRecord>,
  sessionID: string,
  command: string,
) => {
  const { replies, hooks } = makeHarness(sessions);
  const hook = await hooks;
  await hook.event?.({
    event: {
      type: "permission.asked",
      properties: {
        id: "per_1",
        sessionID,
        permission: "bash",
        patterns: [command],
        metadata: { command },
        always: [],
      },
    },
  });
  return replies;
};

const beforeIn = async (
  sessions: Record<string, SessionRecord>,
  sessionID: string,
  command: string,
) => {
  const { hooks } = makeHarness(sessions);
  const hook = await hooks;
  await hook["tool.execute.before"]?.(
    { tool: "bash", sessionID, callID: "call_1" },
    { args: { command } },
  );
};

const buildRootWithGeneral = {
  ses_root: { agent: "build" },
  ses_child: { agent: "general", parentID: "ses_root" },
};

const planRootWithGeneral = {
  ses_root: { agent: "plan" },
  ses_child: { agent: "general", parentID: "ses_root" },
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

    test("buildモードではgit commitも自動承認する", async () => {
      const replies = await ask("build", "git commit -m m");
      expect(replies).toHaveLength(1);
      expect(replies[0].response).toBe("once");
    });

    test("planモードではgit commitを自動承認しない", async () => {
      const replies = await ask("plan", "git commit -m m");
      expect(replies).toHaveLength(0);
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
    test("buildモードの-C付きgit commitは拒否しない", async () => {
      await expect(
        before("build", "git -C repo commit -m m"),
      ).resolves.toBeUndefined();
    });

    test("planモードのgit commitは拒否する", async () => {
      await expect(before("plan", "git commit -m m")).rejects.toThrow(/commit/);
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

  describe("サブエージェントは祖先セッションのモードで判定される", () => {
    test("buildルートのgeneralサブエージェントのgit addを自動承認する", async () => {
      const replies = await askIn(
        buildRootWithGeneral,
        "ses_child",
        "git add .",
      );
      expect(replies).toHaveLength(1);
      expect(replies[0].response).toBe("once");
    });

    test("planルートのgeneralサブエージェントのgit addを自動承認しない", async () => {
      const replies = await askIn(planRootWithGeneral, "ses_child", "git add .");
      expect(replies).toHaveLength(0);
    });

    test("buildルートのgeneralサブエージェントのgit addを拒否しない", async () => {
      await expect(
        beforeIn(buildRootWithGeneral, "ses_child", "git add ."),
      ).resolves.toBeUndefined();
    });

    test("planルートのgeneralサブエージェントのgit addを拒否する", async () => {
      await expect(
        beforeIn(planRootWithGeneral, "ses_child", "git add ."),
      ).rejects.toThrow(/add/);
    });

    test("explorerルートのサブエージェントのgit addを拒否する", async () => {
      await expect(
        beforeIn(
          {
            ses_root: { agent: "explorer" },
            ses_child: { agent: "general", parentID: "ses_root" },
          },
          "ses_child",
          "git add .",
        ),
      ).rejects.toThrow(/add/);
    });
  });
});
