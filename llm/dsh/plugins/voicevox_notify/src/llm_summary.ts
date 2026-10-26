const SUMMARY_PROVIDER = "opencode-go";
const SUMMARY_MODEL = "deepseek-v4.1-flash";
const SUMMARY_SYSTEM_PROMPT = [
  "あなたは音声読み上げ用の要約器です。",
  "20字以内で語尾に「のだ」を付けた要約文を作成して。英字・英単語・アルファベットはすべてカタカナで表記して",
  "コード、箇条書き、Markdown、見出し、絵文字は使わず、そのまま読み上げられる文章だけを返してください。",
].join("\n");
const SUMMARY_INPUT_LIMIT = 4000;
const SUMMARY_MAX_TOKENS = 1000;
const SUMMARY_TIMEOUT_MS = 20_000;

type StreamChunk =
  | { readonly type: "text-delta"; readonly text: string }
  | { readonly type: "finish"; readonly reason: { readonly kind: string } }
  | { readonly type: "block-start" }
  | { readonly type: "reasoning-delta" }
  | { readonly type: "tool-call-delta" }
  | { readonly type: "block-end" }
  | { readonly type: "usage" };

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
    if (chunk.type === "finish") {
      finished = chunk.reason.kind === "stop";
    }
  }
  const summary = texts.join("").trim();
  return finished && summary !== "" ? summary : undefined;
};
