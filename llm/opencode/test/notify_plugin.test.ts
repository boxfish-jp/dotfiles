import { describe, expect, test } from "bun:test";
import { NotifyPlugin } from "../plugins/notify.ts";

type PluginInput = Parameters<typeof NotifyPlugin>[0];

const WAIT_MS = 50;

type Captured = {
  notified: string[];
};

const makeHarness = () => {
  const captured: Captured = { notified: [] };

  const client = {
    app: { log: async () => undefined },
    session: {
      get: async () => ({ data: { parentID: undefined } }),
      messages: async () => ({ data: [] }),
    },
    config: { providers: async () => ({ data: { providers: [] } }) },
  };

  const previousFetch = globalThis.fetch;
  const previousWait = process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS;
  globalThis.fetch = (async (input: URL | string) => {
    const url = typeof input === "string" ? new URL(input) : input;
    captured.notified.push(url.searchParams.get("text") ?? "");
    return {
      ok: true,
      status: 200,
      json: async () => ({}),
      text: async () => "",
    };
  }) as unknown as typeof fetch;
  process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS = String(WAIT_MS);

  const hooks = NotifyPlugin({
    client,
    directory: "/tmp",
  } as unknown as PluginInput);

  const restore = () => {
    globalThis.fetch = previousFetch;
    if (previousWait === undefined) {
      delete process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS;
    } else {
      process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS = previousWait;
    }
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
        expect(h.captured.notified).toEqual(["bashの許可が欲しいのだ"]);
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
        expect(h.captured.notified).toEqual(["bashの許可が欲しいのだ"]);
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
});
