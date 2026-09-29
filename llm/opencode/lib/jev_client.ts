// OpenRouter の decisions API (typesafe/jev) を叩く最小クライアント。
// プロンプトと選択肢を渡すと、各選択肢の確率分布と選択結果を返す。
// fetch は差し替え可能にしてテストから偽応答を injection できるようにする。

export const JEV_ENDPOINT = "https://openrouter.ai/api/alpha/decisions";
export const JEV_MODEL = "typesafe/jev-1.13";

export type JevJudgment = {
  type: "choice";
  choice: string;
  confidence: number;
  probabilities: Record<string, number>;
};

export type JevResponse = {
  answers: { judgment: JevJudgment };
  usage: { input_tokens: number; output_tokens: number; cost: number };
};

export type FetchLike = (
  input: string,
  init: {
    method: string;
    headers: Record<string, string>;
    body: string;
    signal?: AbortSignal;
  },
) => Promise<{
  ok: boolean;
  status: number;
  json: () => Promise<unknown>;
  text: () => Promise<string>;
}>;

export type AskJevParams = {
  prompt: string;
  options: string[];
  instructions: string;
  criteria: Record<string, string>;
  apiKey: string;
  timeoutMs?: number;
  fetchImpl?: FetchLike;
};

const DEFAULT_TIMEOUT_MS = 10_000;

export const askJev = async (
  params: AskJevParams,
): Promise<JevResponse> => {
  const {
    prompt,
    options,
    instructions,
    criteria,
    apiKey,
    timeoutMs = DEFAULT_TIMEOUT_MS,
    fetchImpl,
  } = params;

  const doFetch: FetchLike = fetchImpl ?? ((globalThis.fetch as unknown) as FetchLike);

  const res = await doFetch(JEV_ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: JEV_MODEL,
      state: { prompt },
      questions: {
        judgment: {
          type: "choice",
          instructions,
          criteria: Object.fromEntries(options.map((o) => [o, criteria[o] ?? o])),
        },
      },
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });

  if (!res.ok) {
    throw new Error(`jev HTTP ${res.status}: ${await res.text()}`);
  }
  return (await res.json()) as JevResponse;
};
