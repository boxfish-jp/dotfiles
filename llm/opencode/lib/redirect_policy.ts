import {
  baseName,
  commandName,
  isFlag,
  isInvocationPosition,
  splitSegmentsDetailed,
} from "./shell_parse.ts";

const REDIRECTS = />\s*([^\s|;&]+)/g;

export const isRealFileWrite = (command: string): boolean => {
  for (const match of command.matchAll(REDIRECTS)) {
    const target = match[1];
    if (target.startsWith("/dev/null")) continue;
    if (/^&?\d+$/.test(target)) continue;
    return true;
  }
  return false;
};

export type ViolationScope = "always" | "exec" | "write";

export type OptionViolation = {
  description: string;
  scope: ViolationScope;
};

type OptionPolicy = {
  short: Set<string>;
  longPrefixes: string[];
  execShort: Set<string>;
  execLongPrefixes: string[];
  consumers: Set<string>;
  longArgFlag?: string;
  always?: boolean;
};

const AWK_POLICY: OptionPolicy = {
  short: new Set(["o", "p", "d", "g"]),
  longPrefixes: ["--pro", "--pre", "--dump", "--gen"],
  execShort: new Set(["l", "i"]),
  execLongPrefixes: ["--lo", "--inc"],
  consumers: new Set(["F", "f", "v"]),
  longArgFlag: "W",
};

const SED_POLICY: OptionPolicy = {
  short: new Set(["i"]),
  longPrefixes: ["--in"],
  execShort: new Set(),
  execLongPrefixes: [],
  consumers: new Set(["e", "f"]),
};

const CURL_POLICY: OptionPolicy = {
  short: new Set(["o", "O"]),
  longPrefixes: ["--out", "--remote-name"],
  execShort: new Set(),
  execLongPrefixes: [],
  consumers: new Set([
    "A",
    "b",
    "C",
    "d",
    "D",
    "e",
    "E",
    "F",
    "H",
    "K",
    "m",
    "P",
    "Q",
    "r",
    "T",
    "t",
    "u",
    "U",
    "w",
    "x",
    "X",
  ]),
  always: true,
};

const OPTION_POLICIES: Record<string, OptionPolicy> = {
  awk: AWK_POLICY,
  gawk: AWK_POLICY,
  mawk: AWK_POLICY,
  sed: SED_POLICY,
  curl: CURL_POLICY,
};

const matchesLongPrefix = (raw: string, prefixes: string[]): boolean => {
  const bare = raw.replace(/^-+/, "").split("=")[0];
  return prefixes.some((p) => bare.startsWith(p.slice(2)));
};

const findDangerousOption = (
  tokens: string[],
  startIndex: number,
  policy: OptionPolicy,
): { token: string; scope: ViolationScope } | null => {
  const writeScope: ViolationScope = policy.always ? "always" : "write";
  const execScope: ViolationScope = policy.always ? "always" : "exec";
  for (let k = startIndex + 1; k < tokens.length; k++) {
    const t = tokens[k];
    if (t === "--") return null;
    if (!isFlag(t) || t === "-") continue;
    if (matchesLongPrefix(t, policy.execLongPrefixes))
      return { token: t, scope: execScope };
    if (matchesLongPrefix(t, policy.longPrefixes))
      return { token: t, scope: writeScope };
    if (t.startsWith("--")) continue;
    if (policy.longArgFlag && t === `-${policy.longArgFlag}`) {
      const next = tokens[k + 1];
      if (next && !isFlag(next) && !next.startsWith("--")) {
        if (matchesLongPrefix(next, policy.execLongPrefixes))
          return { token: `${t} ${next}`, scope: execScope };
        if (matchesLongPrefix(next, policy.longPrefixes))
          return { token: `${t} ${next}`, scope: writeScope };
      }
      continue;
    }
    let scope: ViolationScope | null = null;
    for (const ch of t.slice(1)) {
      if (policy.execShort.has(ch)) {
        scope = execScope;
        break;
      }
      if (policy.short.has(ch)) {
        scope = writeScope;
        break;
      }
      if (policy.consumers.has(ch)) break;
    }
    if (scope) return { token: t, scope };
  }
  return null;
};

export const findOptionViolations = (command: string): OptionViolation[] => {
  const violations: OptionViolation[] = [];
  for (const { tokens } of splitSegmentsDetailed(command)) {
    for (let i = 0; i < tokens.length; i++) {
      const name = baseName(tokens[i]);
      const policy = OPTION_POLICIES[name];
      if (!policy) continue;
      if (!isInvocationPosition(tokens, i)) continue;
      const hit = findDangerousOption(tokens, i, policy);
      if (!hit) continue;
      violations.push({
        description: `${name} の ${hit.token}`,
        scope: hit.scope,
      });
    }
  }
  return violations;
};

const AWK_INTERPRETERS = new Set(["awk", "gawk", "mawk"]);

const AWK_EXEC_CONSTRUCTS: Array<[RegExp, string]> = [
  [/(^|[;{}])\s*system\s*\(/, "system() 呼び出し"],
  [/\|&/, "コプロセス |&"],
  [/\|\s*"/, "print のパイプ先コマンド"],
  [/[")]\s*\|\s*getline/, "getline へのコマンドパイプ"],
];

const SED_EXEC_CONSTRUCTS: Array<[RegExp, string]> = [
  [/(^|[;\n])\s*e(?=[;\n\s]|$)/, "e コマンド"],
];

const SED_DELIM_RE = /^[^A-Za-z0-9\s\\]/;

const substituteFlagsAt = (script: string, start: number): string | null => {
  const delim = script[start + 1];
  if (!delim || !SED_DELIM_RE.test(delim)) return null;
  let pos = start + 2;
  let separators = 0;
  while (pos < script.length && separators < 2) {
    const c = script[pos];
    if (c === "\\") {
      pos += 2;
      continue;
    }
    if (c === delim) separators++;
    pos++;
  }
  if (separators < 2) return null;
  let flags = "";
  while (pos < script.length && /[A-Za-z]/.test(script[pos])) {
    flags += script[pos];
    pos++;
  }
  return flags;
};

const hasSedSubstituteExecFlag = (script: string): boolean => {
  for (let i = 0; i < script.length; i++) {
    if (script[i] !== "s") continue;
    if (i > 0 && /[A-Za-z0-9]/.test(script[i - 1])) continue;
    if (substituteFlagsAt(script, i)?.includes("e")) return true;
  }
  return false;
};

export const findEmbeddedExecution = (command: string): string | null => {
  for (const { tokens } of splitSegmentsDetailed(command)) {
    for (let i = 0; i < tokens.length; i++) {
      const name = baseName(tokens[i]);
      const isAwk = AWK_INTERPRETERS.has(name);
      const isSed = name === "sed";
      if ((!isAwk && !isSed) || !isInvocationPosition(tokens, i)) continue;
      for (let k = i + 1; k < tokens.length; k++) {
        const t = tokens[k];
        if (isAwk) {
          for (const [pattern, label] of AWK_EXEC_CONSTRUCTS) {
            if (pattern.test(t)) return `${name} の ${label}`;
          }
        } else {
          for (const [pattern, label] of SED_EXEC_CONSTRUCTS) {
            if (pattern.test(t)) return `${name} の ${label}`;
          }
          if (hasSedSubstituteExecFlag(t))
            return `${name} の s///e フラグ`;
        }
      }
    }
  }
  return null;
};

const PIPE_EXECUTORS = new Set([
  "ash",
  "bash",
  "bun",
  "dash",
  "deno",
  "ksh",
  "node",
  "perl",
  "php",
  "python",
  "python3",
  "ruby",
  "sh",
  "zsh",
]);

export const findPipedExecution = (command: string): string | null => {
  const segments = splitSegmentsDetailed(command);
  for (let i = 1; i < segments.length; i++) {
    if (segments[i].op !== "|") continue;
    const name = commandName(segments[i].tokens);
    if (!PIPE_EXECUTORS.has(name)) continue;
    return `${commandName(segments[i - 1].tokens)} から ${name} へのパイプ実行`;
  }
  return null;
};
