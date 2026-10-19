import {
  baseName,
  commandName,
  isFlag,
  isInvocationPosition,
  isOperandToken,
  SCRIPT_INTERPRETERS,
  splitSegments,
} from "./shell_parse.ts";

const FIND_EXEC_FLAGS = new Set(["-exec", "-execdir", "-ok", "-okdir"]);

// opencode.jsonc の permission.bash deny 規則から構築する拒否コマンド集合。
// config の deny は先頭トークン一致なので timeout/nohup 等のラッパー越しに素通りされる。
// プラグイン側は同じ集合を全起動位置(ラッパー遡及込み)に適用してその穴を塞ぐ。
export type DenyRules = {
  names: ReadonlySet<string>;
  subcommands: ReadonlyMap<string, ReadonlySet<string>>;
};

export const EMPTY_DENY_RULES: DenyRules = {
  names: new Set(),
  subcommands: new Map(),
};

const BARE_COMMAND_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._+-]*$/;

// "rm *" / "sudo*" -> ["rm"] / ["sudo"]、"nix run *" -> ["nix", "run"]。
// "./*" や "find * -exec*" などコマンド名表現でないパターンは null。
const parseCommandPattern = (pattern: string): string[] | null => {
  const base = pattern.endsWith("*") ? pattern.slice(0, -1).trimEnd() : pattern;
  if (base === "" || base.includes("*")) return null;
  const parts = base.split(/\s+/);
  if (parts.length > 2) return null;
  return parts.every((part) => BARE_COMMAND_PATTERN.test(part)) ? parts : null;
};

const bashPatternEntries = (permission: unknown): [string, string][] => {
  if (!permission || typeof permission !== "object" || Array.isArray(permission))
    return [];
  const bash = (permission as Record<string, unknown>).bash;
  if (!bash || typeof bash !== "object" || Array.isArray(bash)) return [];
  return Object.entries(bash as Record<string, unknown>).filter(
    ([, action]) => typeof action === "string",
  ) as [string, string][];
};

const registerPattern = (
  pattern: string,
  names: Set<string>,
  subcommands: Map<string, Set<string>>,
): void => {
  const parts = parseCommandPattern(pattern);
  if (!parts) return;
  if (parts.length === 1) {
    names.add(parts[0]);
    return;
  }
  const subs = subcommands.get(parts[0]) ?? new Set<string>();
  subs.add(parts[1]);
  subcommands.set(parts[0], subs);
};

export const buildDenyRules = (
  permission: unknown,
  agents: unknown,
): DenyRules => {
  const deniedNames = new Set<string>();
  const deniedSubs = new Map<string, Set<string>>();
  for (const [pattern, action] of bashPatternEntries(permission)) {
    if (action === "deny") registerPattern(pattern, deniedNames, deniedSubs);
  }

  // agent 側 allow は global deny に優先(opencode のマージ意味論に合わせる)
  const allowedNames = new Set<string>();
  const allowedSubs = new Map<string, Set<string>>();
  const agentEntries =
    agents && typeof agents === "object" && !Array.isArray(agents)
      ? Object.values(agents as Record<string, unknown>)
      : [];
  for (const agent of agentEntries) {
    const agentPermission =
      agent && typeof agent === "object"
        ? (agent as Record<string, unknown>).permission
        : undefined;
    for (const [pattern, action] of bashPatternEntries(agentPermission)) {
      if (action === "allow") registerPattern(pattern, allowedNames, allowedSubs);
    }
  }
  for (const name of allowedNames) deniedNames.delete(name);

  const subcommands = new Map<string, ReadonlySet<string>>();
  for (const [name, subs] of deniedSubs) {
    const keep = new Set(
      [...subs].filter((sub) => !allowedSubs.get(name)?.has(sub)),
    );
    if (keep.size > 0) subcommands.set(name, keep);
  }
  return { names: deniedNames, subcommands };
};

const findPathInvocation = (tokens: string[]): string | null => {
  for (const [i, token] of tokens.entries()) {
    if (!token.includes("/") || !isOperandToken(token)) continue;
    if (isInvocationPosition(tokens, i)) return token;
  }
  return null;
};

const findInterpreterInvocation = (tokens: string[]): string | null => {
  for (const [i, token] of tokens.entries()) {
    if (!isOperandToken(token)) continue;
    const name = baseName(token);
    if (!SCRIPT_INTERPRETERS.has(name)) continue;
    if (isInvocationPosition(tokens, i)) return name;
  }
  return null;
};

const findDeniedInvocation = (
  tokens: string[],
  rules: DenyRules,
): string | null => {
  for (const [i, token] of tokens.entries()) {
    if (!isOperandToken(token)) continue;
    if (!isInvocationPosition(tokens, i)) continue;
    const name = baseName(token);
    if (rules.names.has(name)) return name;
    const deniedSubs = rules.subcommands.get(name);
    if (!deniedSubs) continue;
    for (let k = i + 1; k < tokens.length; k++) {
      const t = tokens[k];
      if (isFlag(t)) continue;
      const sub = baseName(t);
      if (deniedSubs.has(sub)) return `${name} ${sub}`;
      break;
    }
  }
  return null;
};

const findFindExecInvocation = (tokens: string[]): string | null => {
  if (commandName(tokens) !== "find") return null;
  for (const token of tokens) {
    if (FIND_EXEC_FLAGS.has(token)) return token;
  }
  return null;
};

// 任意コード実行ベクタ(パス実行・インタプリタ・find -exec)の検出。
// build モードでは jev 判定に委ねるため、プラグイン側は非 build モードでのみ使う。
export const findExecutionVector = (command: string): string | null => {
  for (const tokens of splitSegments(command)) {
    const pathHit = findPathInvocation(tokens);
    if (pathHit) return `パス指定コマンド ${pathHit} の直接実行`;

    const interpreterHit = findInterpreterInvocation(tokens);
    if (interpreterHit)
      return `インタプリタ ${interpreterHit} によるスクリプト・コード実行`;

    const findHit = findFindExecInvocation(tokens);
    if (findHit) return `find の ${findHit} 経由の実行`;
  }
  return null;
};

// config deny 規則コマンドのラッパー遡及検出(全モードでハード拒否)。
export const findDeniedCommand = (
  command: string,
  rules: DenyRules,
): string | null => {
  for (const tokens of splitSegments(command)) {
    const deniedHit = findDeniedInvocation(tokens, rules);
    if (deniedHit) return deniedHit;
  }
  return null;
};
