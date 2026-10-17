import { describe, expect, test } from "bun:test";
import { mkdtempSync } from "node:fs";
import { tmpdir, userInfo } from "node:os";
import { isSummaryUser, NotifyPlugin } from "../plugins/notify.ts";

type PluginInput = Parameters<typeof NotifyPlugin>[0];

const WAIT_MS = 50;
const OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions";
const ASSISTANT_TEXT =
  "これはテスト用の長いアシスタント応答テキストです。要約対象になります。";

type HarnessOptions = {
  apiKey?: string | null;
  summaryUsers?: string;
  summary?: string;
  openrouterStatus?: number;
  messages?: Array<{
    info: { role: string };
    parts: Array<{ type: string; text?: string }>;
  }>;
};

type Captured = {
  notified: string[];
  openrouter: Array<{
    url: string;
    headers: Record<string, string>;
    body: Record<string, unknown>;
  }>;
};

const makeHarness = (options: HarnessOptions = {}) => {
  const captured: Captured = { notified: [], openrouter: [] };
  const emptyDataHome =
    options.apiKey === null
      ? mkdtempSync(`${tmpdir()}/notify-auth-`)
      : undefined;
  const messages = options.messages ?? [
    {
      info: { role: "assistant" },
      parts: [{ type: "text", text: ASSISTANT_TEXT }],
    },
  ];
  const summary = options.summary ?? "テスト要約なのだ";
  const status = options.openrouterStatus ?? 200;

  const client = {
    app: { log: async () => undefined },
    session: {
      get: async () => ({ data: { parentID: undefined } }),
      messages: async () => ({ data: messages }),
    },
  };

  const previousFetch = globalThis.fetch;
  const previousEnv = {
    wait: process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS,
    apiKey: process.env.OPENROUTER_API_KEY,
    summaryUsers: process.env.OPENCODE_NOTIFY_SUMMARY_USERS,
    dataHome: process.env.XDG_DATA_HOME,
  };

  globalThis.fetch = (async (input: URL | string, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    if (url.startsWith("http://192.168.68.16")) {
      captured.notified.push(new URL(url).searchParams.get("text") ?? "");
      return {
        ok: true,
        status: 200,
        json: async () => ({}),
        text: async () => "",
      };
    }
    captured.openrouter.push({
      url,
      headers: (init?.headers ?? {}) as Record<string, string>,
      body: JSON.parse(String(init?.body ?? "{}")) as Record<string, unknown>,
    });
    return {
      ok: status < 400,
      status,
      json: async () => ({ choices: [{ message: { content: summary } }] }),
      text: async () => "",
    };
  }) as unknown as typeof fetch;

  process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS = String(WAIT_MS);
  if (options.summaryUsers === undefined) {
    delete process.env.OPENCODE_NOTIFY_SUMMARY_USERS;
  } else {
    process.env.OPENCODE_NOTIFY_SUMMARY_USERS = options.summaryUsers;
  }
  if (options.apiKey === null) {
    delete process.env.OPENROUTER_API_KEY;
    process.env.XDG_DATA_HOME = emptyDataHome;
  } else {
    process.env.OPENROUTER_API_KEY = options.apiKey ?? "test-key";
  }

  const hooks = NotifyPlugin({
    client,
    directory: "/tmp",
  } as unknown as PluginInput);

  const restoreEnv = (name: string, value: string | undefined) => {
    if (value === undefined) delete process.env[name];
    else process.env[name] = value;
  };

  const restore = () => {
    globalThis.fetch = previousFetch;
    restoreEnv("OPENCODE_NOTIFY_PERMISSION_WAIT_MS", previousEnv.wait);
    restoreEnv("OPENROUTER_API_KEY", previousEnv.apiKey);
    restoreEnv("OPENCODE_NOTIFY_SUMMARY_USERS", previousEnv.summaryUsers);
    restoreEnv("XDG_DATA_HOME", previousEnv.dataHome);
  };
  return { captured, hooks, restore };
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const emit = async (
  hooks: Awaited<ReturnType<typeof NotifyPlugin>>,
  type: string,
  properties: Record<string, unknown>,
) => {
  await hooks.event?.({ event: { type, properties } });
};

const completeSession = async (
  h: ReturnType<typeof makeHarness>,
  sessionID = "ses_1",
) => {
  const hooks = await h.hooks;
  await emit(hooks, "session.status", {
    sessionID,
    status: { type: "busy" },
  });
  await emit(hooks, "session.status", {
    sessionID,
    status: { type: "idle" },
  });
};

const askPermission = async (
  h: ReturnType<typeof makeHarness>,
  id: string,
  permission: string,
  command = "ffmpeg -i a.mp4 b.mp4",
) => {
  await emit(await h.hooks, "permission.asked", {
    id,
    sessionID: "ses_1",
    permission,
    patterns: permission === "bash" ? [command] : ["some/target"],
    metadata: permission === "bash" ? { command } : {},
    always: [],
  });
};

const replyPermission = async (
  h: ReturnType<typeof makeHarness>,
  permissionID: string,
  response = "once",
) => {
  await emit(await h.hooks, "permission.replied", {
    sessionID: "ses_1",
    permissionID,
    response,
  });
};

describe("NotifyPlugin", () => {
  describe("permission.askedの通知", () => {
    test("bashの許可要求は待機内に返信が無ければ遅延通知される", async () => {
      const h = makeHarness();
      try {
        await askPermission(h, "per_1", "bash");
        expect(h.captured.notified).toHaveLength(0);
        await sleep(WAIT_MS * 3);
        expect(h.captured.notified).toEqual(["バッシュの許可が欲しいのだ"]);
      } finally {
        h.restore();
      }
    });

    test("bashの許可要求は待機内にpermission.repliedが来ると通知されない", async () => {
      const h = makeHarness();
      try {
        await askPermission(h, "per_1", "bash");
        await replyPermission(h, "per_1", "reject");
        await sleep(WAIT_MS * 3);
        expect(h.captured.notified).toHaveLength(0);
      } finally {
        h.restore();
      }
    });

    test("別のidのpermission.repliedではbashの待機は取消されない", async () => {
      const h = makeHarness();
      try {
        await askPermission(h, "per_1", "bash");
        await replyPermission(h, "per_2");
        await sleep(WAIT_MS * 3);
        expect(h.captured.notified).toEqual(["バッシュの許可が欲しいのだ"]);
      } finally {
        h.restore();
      }
    });

    test("editの許可要求は待機せず即時通知される", async () => {
      const h = makeHarness();
      try {
        await askPermission(h, "per_1", "edit");
        expect(h.captured.notified).toEqual(["編集の許可が欲しいのだ"]);
      } finally {
        h.restore();
      }
    });

    test("questionの許可要求は通知しない", async () => {
      const h = makeHarness();
      try {
        await askPermission(h, "per_1", "question");
        await sleep(WAIT_MS * 3);
        expect(h.captured.notified).toHaveLength(0);
      } finally {
        h.restore();
      }
    });
  });

  describe("応答完了時の要約", () => {
    test("要約対象ユーザーではgemma-4-26b-a4b-it:freeを筆頭にfreeモデルへ要約を依頼し結果を通知する", async () => {
      const h = makeHarness({ summaryUsers: userInfo().username });
      try {
        await completeSession(h);

        expect(h.captured.openrouter).toHaveLength(1);
        const [request] = h.captured.openrouter;
        expect(request.url).toBe(OPENROUTER_API_URL);
        expect(request.headers.Authorization).toBe("Bearer test-key");
        expect(request.body.models).toEqual([
          "google/gemma-4-26b-a4b-it:free",
          "nvidia/nemotron-3-super-120b-a12b:free",
          "cohere/north-mini-code:free",
        ]);
        expect(h.captured.notified).toEqual([
          "応答が完了したのだ",
          "テスト要約なのだ",
        ]);
      } finally {
        h.restore();
      }
    });

    test("要約対象外ユーザーでは要約せず完了通知のみを送る", async () => {
      const h = makeHarness({ summaryUsers: `${userInfo().username}-other` });
      try {
        await completeSession(h);

        expect(h.captured.openrouter).toHaveLength(0);
        expect(h.captured.notified).toEqual(["応答が完了したのだ"]);
      } finally {
        h.restore();
      }
    });

    test("openrouterのキーが無ければ要約せずフォールバックする", async () => {
      const h = makeHarness({ apiKey: null });
      try {
        await completeSession(h);

        expect(h.captured.openrouter).toHaveLength(0);
        expect(h.captured.notified).toEqual([
          "応答が完了したのだ",
          "ひとことで言えないのだ",
        ]);
      } finally {
        h.restore();
      }
    });

    test("openrouterが失敗すると「ひとことで言えないのだ」を通知する", async () => {
      const h = makeHarness({ openrouterStatus: 429 });
      try {
        await completeSession(h);

        expect(h.captured.openrouter).toHaveLength(1);
        expect(h.captured.notified).toEqual([
          "応答が完了したのだ",
          "ひとことで言えないのだ",
        ]);
      } finally {
        h.restore();
      }
    });

    test("最後のメッセージがassistantでなければ要約しない", async () => {
      const h = makeHarness({
        messages: [
          {
            info: { role: "user" },
            parts: [{ type: "text", text: ASSISTANT_TEXT }],
          },
        ],
      });
      try {
        await completeSession(h);

        expect(h.captured.openrouter).toHaveLength(0);
        expect(h.captured.notified).toEqual(["応答が完了したのだ"]);
      } finally {
        h.restore();
      }
    });
  });
});

describe("isSummaryUser", () => {
  test("既定ではboxfishとserverを要約対象にする", () => {
    expect(isSummaryUser("boxfish", {})).toBe(true);
    expect(isSummaryUser("server", {})).toBe(true);
  });

  test("既定ではlaptopやmonitor-serverを要約対象にしない", () => {
    expect(isSummaryUser("laptop", {})).toBe(false);
    expect(isSummaryUser("monitor-server", {})).toBe(false);
  });

  test("OPENCODE_NOTIFY_SUMMARY_USERSで対象を上書きできる", () => {
    expect(
      isSummaryUser("laptop", { OPENCODE_NOTIFY_SUMMARY_USERS: "laptop" }),
    ).toBe(true);
  });
});
