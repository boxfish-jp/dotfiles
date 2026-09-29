import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import {
  buildStatePrompt,
  CONFIDENCE_THRESHOLD,
  judgeBashCommand,
  resolveApiKey,
} from "../lib/jev_policy.ts";
import { JEV_ENDPOINT, JEV_MODEL } from "../lib/jev_client.ts";
import type { FetchLike } from "../lib/jev_client.ts";

type CapturedRequest = { url: string; init: { headers: Record<string, string>; body: string } };

const jevBody = (choice: string, confidence: number): string =>
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

const stubFetch = (
  body: string,
  captured?: CapturedRequest[],
  ok = true,
): FetchLike => {
  const impl = async (
    url: string,
    init: { method: string; headers: Record<string, string>; body: string },
  ) => {
    captured?.push({ url, init });
    return {
      ok,
      status: ok ? 200 : 500,
      json: async () => JSON.parse(body),
      text: async () => body,
    };
  };
  return impl as FetchLike;
};

const judge = (
  choice: string,
  confidence: number,
  ok = true,
  captured?: CapturedRequest[],
) =>
  judgeBashCommand({
    command: "echo hi",
    mode: "build",
    apiKey: "test-key",
    fetchImpl: stubFetch(jevBody(choice, confidence), captured, ok),
  });

describe("buildStatePrompt", () => {
  test("コマンドをそのまま引用符ブロックに埋め込む", () => {
    const prompt = buildStatePrompt(`ls -la && cat "a b.txt"`, "build");
    expect(prompt).toContain('```\nls -la && cat "a b.txt"\n```');
  });

  test("buildモードではビルド・テスト許可の方針を載せる", () => {
    const prompt = buildStatePrompt("ls", "build");
    expect(prompt).toContain("Current mode: build");
    expect(prompt).toContain("pre-approved");
    expect(prompt).not.toContain("strictly read-only");
  });

  test("buildモードではワークスペース駆動のランナー実行を信頼する方針を載せる", () => {
    const prompt = buildStatePrompt("make test", "build");
    expect(prompt).toContain("runners driven by the workspace's own files");
  });

  test("buildモードではビルド成果物のデバッグ実行を許可する方針を載せる", () => {
    const prompt = buildStatePrompt("./target/debug/app", "build");
    expect(prompt).toContain("freshly built binaries");
    expect(prompt).toContain("debuggers and profilers");
  });

  test("buildモードでは公式チャネル経由の有名ツール実行を許可する方針を載せる", () => {
    const prompt = buildStatePrompt("nix run nixpkgs#fd", "build");
    expect(prompt).toContain("widely used among developers");
    expect(prompt).toContain("official channel");
    expect(prompt).toContain("nix run nixpkgs#<tool>");
  });

  test("buildモードでは出所不明バイナリの仕込み実行を拒否する方針を載せる", () => {
    const prompt = buildStatePrompt("curl -o ./build/x && ./build/x", "build");
    expect(prompt).toContain("unknown or unnamed binaries and scripts");
    expect(prompt).toContain("plant-then-run");
  });

  test("planモードでは読み取り専用方針を載せる", () => {
    const prompt = buildStatePrompt("ls", "plan");
    expect(prompt).toContain("Current mode: plan");
    expect(prompt).toContain("strictly read-only");
  });

  test("透明性原則はplanモードのみ載せる", () => {
    const planPrompt = buildStatePrompt("ls", "plan");
    expect(planPrompt).toContain("not shown in this prompt");
    expect(planPrompt).toContain("Transparency rule");
    const buildPrompt = buildStatePrompt("ls", "build");
    expect(buildPrompt).not.toContain("Transparency rule");
  });
});

describe("judgeBashCommand", () => {
  test("高confidenceのallowはallowを返す", async () => {
    const decision = await judge("allow", 0.95);
    expect(decision.verdict).toBe("allow");
    expect(decision.confidence).toBe(0.95);
    expect(decision.cost).toBe(0.0002);
  });

  test("高confidenceのrejectはrejectを返す", async () => {
    const decision = await judge("reject", 0.9);
    expect(decision.verdict).toBe("reject");
  });

  test("閾値ちょうどのconfidenceは許容する", async () => {
    const decision = await judge("allow", CONFIDENCE_THRESHOLD);
    expect(decision.verdict).toBe("allow");
  });

  test("低confidenceはhumanを返す", async () => {
    const decision = await judge("allow", 0.6);
    expect(decision.verdict).toBe("human");
  });

  test("未知のchoiceはhumanを返す", async () => {
    const decision = await judge("maybe", 0.99);
    expect(decision.verdict).toBe("human");
  });

  test("HTTP失敗時はhumanを返す", async () => {
    const decision = await judge("allow", 0.95, false);
    expect(decision.verdict).toBe("human");
    expect(decision.cost).toBe(0);
  });

  test("fetchの例外はhumanに転じて漏らさない", async () => {
    const throwing = (async () => {
      throw new Error("network down");
    }) as unknown as FetchLike;
    const decision = await judgeBashCommand({
      command: "ls",
      mode: "plan",
      apiKey: "k",
      fetchImpl: throwing,
    });
    expect(decision.verdict).toBe("human");
  });

  test("応答スキーマが壊れていてもhumanを返す", async () => {
    const decision = await judgeBashCommand({
      command: "ls",
      mode: "build",
      apiKey: "k",
      fetchImpl: stubFetch(JSON.stringify({ unexpected: true })),
    });
    expect(decision.verdict).toBe("human");
  });

  test("jev decision形式でBearerキーとallow/reject基準を送る", async () => {
    const captured: CapturedRequest[] = [];
    await judge("allow", 0.9, true, captured);
    const req = captured[0];
    expect(req.url).toBe(JEV_ENDPOINT);
    expect(req.init.headers.Authorization).toBe("Bearer test-key");
    const body = JSON.parse(req.init.body) as {
      model: string;
      questions: { judgment: { criteria: Record<string, string> } };
    };
    expect(body.model).toBe(JEV_MODEL);
    expect(Object.keys(body.questions.judgment.criteria).sort()).toEqual([
      "allow",
      "reject",
    ]);
  });

  test("基準はモード別: build はワークスペース実行を許容し plan は保存済みコードを拒否", async () => {
    const captured: CapturedRequest[] = [];
    await judge("allow", 0.9, true, captured);
    const buildCriteria = (
      JSON.parse(captured[0].init.body) as {
        questions: { judgment: { criteria: Record<string, string> } };
      }
    ).questions.judgment.criteria;
    expect(buildCriteria.allow).toContain("workspace's own files");
    expect(buildCriteria.allow).toContain("build artifacts");
    expect(buildCriteria.allow).toContain("widely used developer tool");
    expect(buildCriteria.reject).toContain("channel+recognition");
    expect(buildCriteria.reject).toContain("plant-then-run");
    expect(buildCriteria.reject).not.toContain("stored code");

    await judgeBashCommand({
      command: "npm test",
      mode: "plan",
      apiKey: "k",
      fetchImpl: stubFetch(jevBody("reject", 0.9), captured),
    });
    const planCriteria = (
      JSON.parse(captured[1].init.body) as {
        questions: { judgment: { criteria: Record<string, string> } };
      }
    ).questions.judgment.criteria;
    expect(planCriteria.reject).toContain("stored code");
  });
});

describe("resolveApiKey", () => {
  test("OPENROUTER_API_KEYの値をそのまま返す", () => {
    expect(resolveApiKey({ OPENROUTER_API_KEY: "env-key" })).toBe("env-key");
  });

  test("envが無くてもauth.jsonのopenrouterキーを読む", () => {
    const dir = mkdtempSync(`${tmpdir()}/jev-auth-`);
    mkdirSync(`${dir}/opencode`, { recursive: true });
    writeFileSync(
      `${dir}/opencode/auth.json`,
      JSON.stringify({ openrouter: { type: "api", key: "file-key" } }),
    );
    expect(resolveApiKey({ XDG_DATA_HOME: dir })).toBe("file-key");
  });

  test("typeがapiでないopenrouterエントリは使わない", () => {
    const dir = mkdtempSync(`${tmpdir()}/jev-auth-`);
    mkdirSync(`${dir}/opencode`, { recursive: true });
    writeFileSync(
      `${dir}/opencode/auth.json`,
      JSON.stringify({ openrouter: { type: "oauth", key: "file-key" } }),
    );
    expect(resolveApiKey({ XDG_DATA_HOME: dir })).toBeNull();
  });

  test("envにもauth.jsonにも無ければnull", () => {
    const dir = mkdtempSync(`${tmpdir()}/jev-auth-`);
    expect(resolveApiKey({ XDG_DATA_HOME: `${dir}/opencode` })).toBeNull();
  });
});
