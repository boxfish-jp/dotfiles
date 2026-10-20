import { readFileSync, readlinkSync, statSync } from "node:fs";
import { homedir } from "node:os";
import type { PluginInput } from "@opencode-ai/plugin";
import {
  baseName,
  isFlag,
  isInvocationPosition,
  isOperandToken,
  SCRIPT_INTERPRETERS,
  splitSegmentsDetailed,
} from "./shell_parse.ts";

export type JevContext = {
  workspaceDir?: string;
  facts: string[];
  scriptSections: string[];
  userMessage?: string;
  recentAllowed: string[];
};

export const EMPTY_JEV_CONTEXT: JevContext = {
  facts: [],
  scriptSections: [],
  recentAllowed: [],
};

type OpencodeClient = PluginInput["client"];

const SCRIPT_CONTENT_BUDGET_CHARS = 4096;
const USER_MESSAGE_CHARS = 400;

const SCRIPT_SUFFIX =
  /\.(sh|bash|zsh|ash|dash|ksh|py|pyw|js|mjs|cjs|ts|rb|pl|pm|php|lua)$/i;

const PATH_UNSAFE = /[\s"'`$(){};&|<>!]/;

const looksLikePath = (token: string): boolean =>
  token.length > 2 &&
  !PATH_UNSAFE.test(token) &&
  (token.startsWith("/") ||
    token.startsWith("./") ||
    token.startsWith("../") ||
    token.startsWith("~/") ||
    SCRIPT_SUFFIX.test(token));

const expandTilde = (path: string): string =>
  path.replace(/^~(?=\/|$)/, homedir());

const resolveFsPath = (path: string, dir?: string): string => {
  if (path.startsWith("/") || path.startsWith("~/")) return expandTilde(path);
  if (dir === undefined) return path;
  return `${dir.endsWith("/") ? dir : `${dir}/`}${path}`;
};

const workspaceRelation = (path: string, dir?: string): string => {
  if (dir === undefined) return "ワークスペース不明";
  const abs = expandTilde(path);
  if (!abs.startsWith("/")) return "ワークスペース内 (cwd からの相対パス)";
  const root = dir.endsWith("/") ? dir.slice(0, -1) : dir;
  return abs === root || abs.startsWith(`${root}/`)
    ? "ワークスペース内"
    : "ワークスペース外";
};

const statFact = (path: string, dir?: string): string => {
  try {
    const stats = statSync(resolveFsPath(path, dir));
    const kind = stats.isDirectory() ? "ディレクトリ" : "ファイル";
    const link = stats.isSymbolicLink()
      ? ` シムリンク -> ${readlinkSync(resolveFsPath(path, dir))}`
      : "";
    return `${path}: ${kind}, ${stats.size} バイト, ${workspaceRelation(path, dir)}${link}`;
  } catch {
    return `${path}: 判定時点で存在しない`;
  }
};

type ScriptRead =
  | { kind: "content"; text: string }
  | { kind: "missing" }
  | { kind: "unreadable" };

const readScript = (path: string, dir?: string): ScriptRead => {
  try {
    return {
      kind: "content",
      text: readFileSync(resolveFsPath(path, dir), "utf8"),
    };
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    return code === "ENOENT" ? { kind: "missing" } : { kind: "unreadable" };
  }
};

const unreadableCode = (path: string, dir?: string): string =>
  `${path}: スクリプト位置のコードは判定時点で読めない (挙動を検証できない), ${workspaceRelation(path, dir)}`;

const missingCode = (path: string, dir?: string): string =>
  `${path}: 判定時点で存在しない (このコマンド本文だけでは挙動を検証できない), ${workspaceRelation(path, dir)}`;

const isShebangScript = (content: string): boolean => {
  if (!content.startsWith("#!")) return false;
  const tokens = content.split("\n", 1)[0].slice(2).trim().split(/\s+/);
  const name = baseName(tokens[0] ?? "");
  const interpreter = name === "env" ? baseName(tokens[1] ?? "") : name;
  return SCRIPT_INTERPRETERS.has(interpreter);
};

type ScriptRef = {
  path: string;
  reason: "interpreter-operand" | "shebang";
};

export type CommandFacts = { facts: string[]; scriptSections: string[] };

export const collectCommandFacts = (
  command: string,
  workspaceDir?: string,
): CommandFacts => {
  const facts: string[] = [];
  const scriptSections: string[] = [];
  const statPaths: string[] = [];
  const statSeen = new Set<string>();
  const scriptRefs = new Map<string, ScriptRef["reason"]>();
  const segmentViews: string[] = [];

  for (const { tokens, op } of splitSegmentsDetailed(command)) {
    segmentViews.push(`${op ? `[${op}] ` : ""}${tokens.join(" ")}`);
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i];
      if (!isOperandToken(token)) continue;
      if (looksLikePath(token)) {
        if (isInvocationPosition(tokens, i)) {
          const probe = readScript(token, workspaceDir);
          if (probe.kind === "content" && isShebangScript(probe.text))
            scriptRefs.set(token, "shebang");
        }
        if (!statSeen.has(token)) {
          statSeen.add(token);
          statPaths.push(token);
        }
      }
      if (!SCRIPT_INTERPRETERS.has(baseName(token))) continue;
      if (!isInvocationPosition(tokens, i)) continue;
      for (let j = i + 1; j < tokens.length; j++) {
        if (isFlag(tokens[j])) continue;
        if (!isOperandToken(tokens[j])) continue;
        if (looksLikePath(tokens[j])) {
          if (!scriptRefs.has(tokens[j]))
            scriptRefs.set(tokens[j], "interpreter-operand");
          break;
        }
      }
    }
  }

  facts.push(`cwd (ワークスペース): ${workspaceDir ?? "不明"}`);
  facts.push(`解析済みセグメント: ${segmentViews.join(" ;; ")}`);
  const statFactByPath = new Map(
    statPaths.map((path) => [path, statFact(path, workspaceDir)]),
  );
  for (const path of statPaths) {
    if (scriptRefs.has(path)) continue;
    facts.push(statFactByPath.get(path) ?? statFact(path, workspaceDir));
  }

  let budget = SCRIPT_CONTENT_BUDGET_CHARS;
  for (const [path, reason] of scriptRefs) {
    const read = readScript(path, workspaceDir);
    if (read.kind === "missing") {
      facts.push(missingCode(path, workspaceDir));
      continue;
    }
    if (read.kind === "unreadable") {
      facts.push(statFactByPath.get(path) ?? statFact(path, workspaceDir));
      facts.push(unreadableCode(path, workspaceDir));
      continue;
    }
    if (reason === "shebang" && !isShebangScript(read.text)) continue;
    if (budget <= 0) {
      scriptSections.push(`--- ${path}: 内容省略 (文字数枠を消費済み) ---`);
      continue;
    }
    const shown = read.text.slice(0, budget);
    budget -= shown.length;
    const note =
      shown.length < read.text.length
        ? ` (先頭 ${shown.length} / 全 ${read.text.length} 文字を表示)`
        : "";
    scriptSections.push(`--- ${path} ---${note}\n${shown}\n--- 終わり ---`);
  }
  return { facts, scriptSections };
};

type MessageEntry = {
  info?: { role?: string };
  parts?: Array<{ type?: string; text?: string }>;
};

export const fetchLatestUserMessage = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<string | undefined> => {
  try {
    const { data } = await client.session.messages({ path: { id: sessionID } });
    const entries = (data ?? []) as MessageEntry[];
    for (let i = entries.length - 1; i >= 0; i--) {
      if (entries[i]?.info?.role !== "user") continue;
      const text = (entries[i].parts ?? [])
        .filter((part) => part.type === "text")
        .map((part) => part.text ?? "")
        .join("\n")
        .trim();
      if (!text) return undefined;
      return text.length > USER_MESSAGE_CHARS
        ? `${text.slice(0, USER_MESSAGE_CHARS)}…(truncated)`
        : text;
    }
    return undefined;
  } catch {
    return undefined;
  }
};
