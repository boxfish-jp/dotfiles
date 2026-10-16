import { describe, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolveApiKey } from "../lib/openrouter_key.ts";

describe("resolveApiKey", () => {
  test("OPENROUTER_API_KEYの値をそのまま返す", () => {
    expect(resolveApiKey({ OPENROUTER_API_KEY: "env-key" })).toBe("env-key");
  });

  test("envが無くてもauth.jsonのopenrouterキーを読む", () => {
    const dir = mkdtempSync(`${tmpdir()}/openrouter-auth-`);
    mkdirSync(`${dir}/opencode`, { recursive: true });
    writeFileSync(
      `${dir}/opencode/auth.json`,
      JSON.stringify({ openrouter: { type: "api", key: "file-key" } }),
    );
    expect(resolveApiKey({ XDG_DATA_HOME: dir })).toBe("file-key");
  });

  test("typeがapiでないopenrouterエントリは使わない", () => {
    const dir = mkdtempSync(`${tmpdir()}/openrouter-auth-`);
    mkdirSync(`${dir}/opencode`, { recursive: true });
    writeFileSync(
      `${dir}/opencode/auth.json`,
      JSON.stringify({ openrouter: { type: "oauth", key: "file-key" } }),
    );
    expect(resolveApiKey({ XDG_DATA_HOME: dir })).toBeNull();
  });

  test("envにもauth.jsonにも無ければnull", () => {
    const dir = mkdtempSync(`${tmpdir()}/openrouter-auth-`);
    expect(resolveApiKey({ XDG_DATA_HOME: `${dir}/opencode` })).toBeNull();
  });
});
