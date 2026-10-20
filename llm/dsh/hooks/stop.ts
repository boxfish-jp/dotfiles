import { mkdirSync, statSync, writeFileSync } from "node:fs";
import { basename } from "node:path";
import { readHookPayload } from "../lib/hook_io.ts";

const NOTIFY_URL = "http://192.168.68.16:50020/";
const NOTIFY_THROTTLE_MS = 10_000;
const NOTIFY_CHANNEL = "1";
const NOTIFY_CHARACTER = "3";
const REQUEST_TIMEOUT_MS = 3_000;
const COMPLETED_TEXT = "応答が完了したのだ";

const stateDir = (): string => {
  const dataHome =
    process.env.XDG_STATE_HOME ?? `${process.env.HOME}/.local/state`;
  return `${dataHome}/dsh-hooks`;
};

const throttleKey = (payload: ReturnType<typeof readHookPayload>): string => {
  const raw = payload.session_id || basename(payload.cwd ?? "dsh");
  return raw.replace(/[^A-Za-z0-9._-]/g, "-");
};

const recentlyNotified = (key: string): boolean => {
  const file = `${stateDir()}/notify-${key}`;
  try {
    if (Date.now() - statSync(file).mtimeMs < NOTIFY_THROTTLE_MS) return true;
  } catch {
    mkdirSync(stateDir(), { recursive: true });
  }
  writeFileSync(file, String(Date.now()));
  return false;
};

const run = async (): Promise<void> => {
  const payload = readHookPayload();
  if (recentlyNotified(throttleKey(payload))) return;
  const url = new URL(NOTIFY_URL);
  url.searchParams.set("text", COMPLETED_TEXT);
  url.searchParams.set("channel", NOTIFY_CHANNEL);
  url.searchParams.set("character", NOTIFY_CHARACTER);
  await fetch(url, {
    method: "POST",
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  }).catch(() => undefined);
};

await run().catch(() => undefined);
