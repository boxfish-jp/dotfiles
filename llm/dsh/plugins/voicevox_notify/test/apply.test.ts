import assert from "node:assert/strict";
import { describe, test } from "node:test";
import { apply } from "../dist/index.js";

const SUMMARY_INPUT_LIMIT = 4000;
const DONE_NOTIFICATION = "応答が完了したのだ";
const SUMMARY_FAILURE_NOTIFICATION = "一言で言えないのだ";

type ApplyContext = Parameters<typeof apply>[0];
type Listener = (...args: unknown[]) => unknown;

type Harness = {
  ctx: ApplyContext;
  emit(event: string, ...args: unknown[]): unknown;
};

type StubChunk =
  | { type: "text-delta"; text: string }
  | { type: "finish"; reason: { kind: string } };

type LlmRequest = {
  provider: string;
  model: string;
  sessionId: string;
  system: string;
  messages: Array<{
    role: string;
    content: Array<{ type: string; text: string }>;
  }>;
  maxTokens: number;
  reasoningEffort?: string;
};

type LlmStub = {
  requests: LlmRequest[];
  llm: {
    resolveModelInfo(): Promise<{
      reasoning: { efforts: Array<{ id: string }> };
    }>;
    stream(options: LlmRequest): AsyncIterable<StubChunk>;
  };
};

type LlmOptions = {
  readonly efforts?: readonly string[];
};

const textDelta = (text: string): StubChunk => ({ type: "text-delta", text });

const finishChunk = (kind: string): StubChunk => ({
  type: "finish",
  reason: { kind },
});

const createLlm = (
  chunks: readonly StubChunk[],
  options: LlmOptions = {},
): LlmStub => {
  const requests: LlmRequest[] = [];
  const efforts = options.efforts ?? ["off"];
  return {
    requests,
    llm: {
      async resolveModelInfo() {
        return { reasoning: { efforts: efforts.map((id) => ({ id })) } };
      },
      stream(request: LlmRequest) {
        requests.push(request);
        return (async function* () {
          for (const chunk of chunks) yield chunk;
        })();
      },
    },
  };
};

const createUnavailableLlm = (): LlmStub["llm"] => ({
  resolveModelInfo() {
    return Promise.reject(new Error("summary model is unavailable"));
  },
  stream() {
    throw new Error("must not stream");
  },
});

const createHarness = (
  llm: LlmStub["llm"] = createUnavailableLlm(),
): Harness => {
  const listeners = new Map<string, Listener[]>();
  const ctx = {
    llm,
    on(event: string, listener: Listener): () => void {
      const registered = listeners.get(event) ?? [];
      registered.push(listener);
      listeners.set(event, registered);
      return () => {};
    },
  };
  return {
    ctx: ctx as unknown as ApplyContext,
    emit(event, ...args) {
      let result: unknown;
      for (const listener of listeners.get(event) ?? []) {
        result = listener(...args);
      }
      return result;
    },
  };
};

const mainSession = (id = "session-1") => ({ id, header: {} });

const subagentSession = (id = "child-session") => ({
  id,
  header: { origin: "subagent" as const },
});

const textBlock = (text: string) => ({ type: "text", text });

const toolCallBlock = () => ({
  type: "tool-call",
  id: "call-1",
  name: "bash",
  arguments: "{}",
});

const assistantMessage = (
  turn: number,
  content: Array<{ type: string; text?: string }>,
) => ({
  type: "assistant/message",
  data: { turn, step: 1, message: { content } },
});

const turnEnd = (turn: number) => ({
  type: "turn/end",
  data: { turn, reason: { kind: "completed" } },
});

const captureSpokenTexts = (): { texts: string[]; restore(): void } => {
  const originalFetch = globalThis.fetch;
  const texts: string[] = [];
  (globalThis as { fetch: typeof fetch }).fetch = ((
    input: string | URL | Request,
  ) => {
    texts.push(new URL(String(input)).searchParams.get("text") ?? "");
    return Promise.resolve(new Response("", { status: 200 }));
  }) as typeof fetch;
  return {
    texts,
    restore() {
      (globalThis as { fetch: typeof fetch }).fetch = originalFetch;
    },
  };
};

describe("apply", () => {
  test("turn/endで最後のassistant/messageを要約に渡して読み上げる", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([textDelta("要約"), finishChunk("stop")]);
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("確認するのだ")]),
      );
      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("最終的な応答なのだ")]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.deepEqual(capture.texts, [DONE_NOTIFICATION, "要約"]);
      assert.deepEqual(stub.requests[0].messages, [
        {
          role: "user",
          content: [{ type: "text", text: "最終的な応答なのだ" }],
        },
      ]);
    } finally {
      capture.restore();
    }
  });

  test("ツール呼び出しだけのメッセージでは要約対象を上書きしない", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([textDelta("要約"), finishChunk("stop")]);
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("調べるのだ")]),
      );
      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [toolCallBlock()]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.deepEqual(capture.texts, [DONE_NOTIFICATION, "要約"]);
      assert.deepEqual(stub.requests[0].messages, [
        { role: "user", content: [{ type: "text", text: "調べるのだ" }] },
      ]);
    } finally {
      capture.restore();
    }
  });

  test("テキストを含まないターンでは何も読み上げない", async () => {
    const capture = captureSpokenTexts();
    try {
      const harness = createHarness();
      apply(harness.ctx);

      harness.emit(
        "session/event",
        mainSession(),
        assistantMessage(1, [toolCallBlock()]),
      );
      await harness.emit("session/event", mainSession(), turnEnd(1));

      assert.deepEqual(capture.texts, []);
    } finally {
      capture.restore();
    }
  });

  test("別のターンのテキストを再利用しない", async () => {
    const capture = captureSpokenTexts();
    try {
      const harness = createHarness();
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(2, [textBlock("二ターン目の応答")]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.deepEqual(capture.texts, []);
    } finally {
      capture.restore();
    }
  });

  test("サブエージェントのターンは読み上げない", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([textDelta("子の要約"), finishChunk("stop")]);
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const child = subagentSession();

      harness.emit(
        "session/event",
        child,
        assistantMessage(1, [textBlock("子の応答")]),
      );
      await harness.emit("session/event", child, turnEnd(1));

      assert.deepEqual(capture.texts, []);
      assert.deepEqual(stub.requests, []);
    } finally {
      capture.restore();
    }
  });

  test("user-questions/requestで質問を通知する", async () => {
    const capture = captureSpokenTexts();
    try {
      const harness = createHarness();
      apply(harness.ctx);
      let continued = 0;

      await harness.emit("user-questions/request", {}, async () => {
        continued += 1;
      });

      assert.deepEqual(capture.texts, ["質問があるのだ"]);
      assert.equal(continued, 1);
    } finally {
      capture.restore();
    }
  });

  test("approval/requestで承認依頼を通知する", async () => {
    const capture = captureSpokenTexts();
    try {
      const harness = createHarness();
      apply(harness.ctx);
      let continued = 0;

      await harness.emit("approval/request", {}, async () => {
        continued += 1;
      });

      assert.deepEqual(capture.texts, ["許可を求められているのだ"]);
      assert.equal(continued, 1);
    } finally {
      capture.restore();
    }
  });

  test("固定ルートのllmで要約した結果を読み上げる", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([
        textDelta("テストは"),
        textDelta("全部通った"),
        finishChunk("stop"),
      ]);
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("長い応答本文")]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.deepEqual(capture.texts, [
        DONE_NOTIFICATION,
        "テストは全部通った",
      ]);
      assert.equal(stub.requests.length, 1);
      assert.equal(stub.requests[0].provider, "opencode-go");
      assert.equal(stub.requests[0].model, "deepseek-v4.1-flash");
      assert.equal(stub.requests[0].sessionId, "session-1");
      assert.equal(stub.requests[0].reasoningEffort, "off");
      assert.deepEqual(stub.requests[0].messages, [
        { role: "user", content: [{ type: "text", text: "長い応答本文" }] },
      ]);
    } finally {
      capture.restore();
    }
  });

  test("思考オフを提供しないモデルにはreasoningEffortを指定しない", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([textDelta("要約"), finishChunk("stop")], {
        efforts: ["low", "high"],
      });
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("応答")]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.equal(stub.requests[0].reasoningEffort, undefined);
    } finally {
      capture.restore();
    }
  });

  test("要約の入力は上限までに切り詰める", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([textDelta("要約"), finishChunk("stop")]);
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("あ".repeat(5000))]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.equal(
        stub.requests[0].messages[0].content[0].text.length,
        SUMMARY_INPUT_LIMIT,
      );
    } finally {
      capture.restore();
    }
  });

  test("要約がstop以外で終わったら要約できない旨を読み上げる", async () => {
    const capture = captureSpokenTexts();
    try {
      const stub = createLlm([
        textDelta("途中まで"),
        finishChunk("max-tokens"),
      ]);
      const harness = createHarness(stub.llm);
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("生の応答")]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.deepEqual(capture.texts, [
        DONE_NOTIFICATION,
        SUMMARY_FAILURE_NOTIFICATION,
      ]);
    } finally {
      capture.restore();
    }
  });

  test("要約のルートが解決できなければ要約できない旨を読み上げる", async () => {
    const capture = captureSpokenTexts();
    try {
      const harness = createHarness();
      apply(harness.ctx);
      const session = mainSession();

      harness.emit(
        "session/event",
        session,
        assistantMessage(1, [textBlock("生の応答")]),
      );
      await harness.emit("session/event", session, turnEnd(1));

      assert.deepEqual(capture.texts, [
        DONE_NOTIFICATION,
        SUMMARY_FAILURE_NOTIFICATION,
      ]);
    } finally {
      capture.restore();
    }
  });
});
