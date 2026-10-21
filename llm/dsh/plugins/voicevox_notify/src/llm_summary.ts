const SUMMARY_PROVIDER = "opencode-go";
const SUMMARY_MODEL = "deepseek-v4.1-flash";
const SUMMARY_SYSTEM_PROMPT = [
  "あなたは音声読み上げ用の要約器です。",
  "与えられたアシスタントの応答を、日本語の話し言葉で1〜2文、120文字以内に要約してください。",
  "コード、箇条書き、Markdown、見出し、絵文字は使わず、そのまま読み上げられる文章だけを返してください。",
].join("\n");
const SUMMARY_INPUT_LIMIT = 4000;
const SUMMARY_MAX_TOKENS = 300;
const SUMMARY_TIMEOUT_MS = 20_000;

type StreamChunk =
  | { readonly type: "text-delta"; readonly text: string }
  | { readonly type: "finish"; readonly reason: { readonly kind: string } };

type OneShotRequest = {
  readonly provider: string;
  readonly model: string;
  readonly sessionId: string;
  readonly system: string;
  readonly messages: readonly {
    readonly role: "user";
    readonly content: readonly {
      readonly type: "text";
      readonly text: string;
    }[];
  }[];
  readonly maxTokens: number;
  readonly reasoningEffort?: string;
  readonly signal: AbortSignal;
};

type LlmModelInfo = {
  readonly reasoning?: {
    readonly efforts: readonly { readonly id: string }[];
  };
};

export type LlmRuntime = {
  stream(options: OneShotRequest): AsyncIterable<StreamChunk>;
  resolveModelInfo(
    provider: string,
    model: string,
    signal?: AbortSignal,
  ): Promise<LlmModelInfo>;
};

const thinkingOffEffort = async (
  llm: LlmRuntime,
  signal: AbortSignal,
): Promise<string | undefined> => {
  const model = await llm.resolveModelInfo(
    SUMMARY_PROVIDER,
    SUMMARY_MODEL,
    signal,
  );
  const offered = model.reasoning?.efforts.some(
    (effort) => effort.id === "off",
  );
  return offered === true ? "off" : undefined;
};

export const summarize = async (
  llm: LlmRuntime,
  text: string,
  sessionId: string,
): Promise<string | undefined> => {
  const signal = AbortSignal.timeout(SUMMARY_TIMEOUT_MS);
  const reasoningEffort = await thinkingOffEffort(llm, signal);
  const texts: string[] = [];
  let finished = false;
  for await (const chunk of llm.stream({
    provider: SUMMARY_PROVIDER,
    model: SUMMARY_MODEL,
    sessionId,
    system: SUMMARY_SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: [{ type: "text", text: text.slice(0, SUMMARY_INPUT_LIMIT) }],
      },
    ],
    maxTokens: SUMMARY_MAX_TOKENS,
    reasoningEffort,
    signal,
  })) {
    if (chunk.type === "text-delta") {
      texts.push(chunk.text);
      continue;
    }
    finished = chunk.reason.kind === "stop";
  }
  const summary = texts.join("").trim();
  return finished && summary !== "" ? summary : undefined;
};
