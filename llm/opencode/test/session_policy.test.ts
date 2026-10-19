import { describe, expect, test } from "bun:test";
import { isBuildSession, isPlanSession } from "../lib/session_policy.ts";

type SessionRecord = { agent?: string; parentID?: string };

type Client = {
  session: { get: (opts: { path: { id: string } }) => Promise<unknown> };
};

const makeClient = (
  sessions: Record<string, SessionRecord>,
): { client: Client; requested: string[] } => {
  const requested: string[] = [];
  const client = {
    session: {
      get: async ({ path }: { path: { id: string } }) => {
        requested.push(path.id);
        return { data: sessions[path.id] };
      },
    },
  };
  return { client, requested };
};

describe("isPlanSession", () => {
  test("自分自身のエージェントがplanならtrueを返す", async () => {
    const { client } = makeClient({ ses_1: { agent: "plan" } });
    await expect(isPlanSession(client, "ses_1")).resolves.toBe(true);
  });

  test("explorerエージェントもtrueを返す", async () => {
    const { client } = makeClient({ ses_1: { agent: "explorer" } });
    await expect(isPlanSession(client, "ses_1")).resolves.toBe(true);
  });

  test("祖先にplanを持つサブエージェントはtrueを返す", async () => {
    const { client } = makeClient({
      ses_root: { agent: "plan" },
      ses_child: { agent: "general", parentID: "ses_root" },
    });
    await expect(isPlanSession(client, "ses_child")).resolves.toBe(true);
  });

  test("build系統のサブエージェントはfalseを返す", async () => {
    const { client } = makeClient({
      ses_root: { agent: "build" },
      ses_child: { agent: "general", parentID: "ses_root" },
    });
    await expect(isPlanSession(client, "ses_child")).resolves.toBe(false);
  });

  test("ルートまでparentIDを辿る", async () => {
    const { client, requested } = makeClient({
      ses_a: { agent: "general", parentID: "ses_b" },
      ses_b: { agent: "general", parentID: "ses_c" },
      ses_c: { agent: "build" },
    });
    await expect(isPlanSession(client, "ses_a")).resolves.toBe(false);
    expect(requested).toEqual(["ses_a", "ses_b", "ses_c"]);
  });

  test("parentID循環では無限ループせず打ち切る", async () => {
    const { client } = makeClient({
      ses_a: { agent: "general", parentID: "ses_b" },
      ses_b: { agent: "general", parentID: "ses_a" },
    });
    await expect(isPlanSession(client, "ses_a")).resolves.toBe(false);
  });

  test("最大深さを越えた祖先は走査しない", async () => {
    const sessions: Record<string, SessionRecord> = {};
    for (let i = 0; i < 20; i++) {
      sessions[`ses_${i}`] =
        i === 19
          ? { agent: "plan" }
          : { agent: "general", parentID: `ses_${i + 1}` };
    }
    const { client, requested } = makeClient(sessions);
    await expect(isPlanSession(client, "ses_0")).resolves.toBe(false);
    expect(requested).toHaveLength(16);
  });

  test("セッション取得失敗はfalseを返す", async () => {
    const client = {
      session: {
        get: async () => {
          throw new Error("session not found");
        },
      },
    };
    await expect(isPlanSession(client, "ses_1")).resolves.toBe(false);
  });
});

describe("isBuildSession", () => {
  test("plan系統でなければtrueを返す", async () => {
    const { client } = makeClient({ ses_1: { agent: "build" } });
    await expect(isBuildSession(client, "ses_1")).resolves.toBe(true);
  });

  test("plan系統ならfalseを返す", async () => {
    const { client } = makeClient({
      ses_root: { agent: "plan" },
      ses_child: { agent: "general", parentID: "ses_root" },
    });
    await expect(isBuildSession(client, "ses_child")).resolves.toBe(false);
  });
});
