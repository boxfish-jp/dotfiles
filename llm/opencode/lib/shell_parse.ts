const WRAPPERS = new Set([
  "busybox",
  "command",
  "env",
  "nice",
  "nohup",
  "stdbuf",
  "sudo",
  "time",
  "timeout",
  "xargs",
]);

const SEGMENT_CHARS = new Set(["\n", "|", "&", ";", "(", ")"]);

export const isFlag = (token: string): boolean => token.startsWith("-");

const isNumber = (token: string): boolean => /^\d+$/.test(token);

const isAssignment = (token: string): boolean => /^[A-Za-z_]\w*=/.test(token);

export const baseName = (token: string): string => {
  const parts = token.split("/");
  return parts[parts.length - 1] ?? token;
};

export type Segment = { tokens: string[]; op: string | null };

export const splitSegmentsDetailed = (command: string): Segment[] => {
  const segments: Segment[] = [];
  let tokens: string[] = [];
  let current = "";
  let quote: string | null = null;
  let pendingOp: string | null = null;

  const flushToken = () => {
    if (current !== "") tokens.push(current);
    current = "";
  };
  const flushSegment = () => {
    flushToken();
    if (tokens.length > 0) segments.push({ tokens, op: pendingOp });
    tokens = [];
    pendingOp = null;
  };

  for (let i = 0; i < command.length; i++) {
    const c = command[i];
    if (quote) {
      if (c === "\\" && quote === '"') {
        current += c + (command[i + 1] ?? "");
        i++;
        continue;
      }
      if (c === quote) {
        quote = null;
        continue;
      }
      current += c;
      continue;
    }
    if (c === "'" || c === '"') {
      quote = c;
      continue;
    }
    if (c === "\\") {
      current += command[i + 1] ?? "";
      i++;
      continue;
    }
    if (SEGMENT_CHARS.has(c)) {
      const next = command[i + 1];
      if ((c === "|" || c === "&" || c === ";") && next === c) {
        flushSegment();
        pendingOp = c + c;
        i++;
        continue;
      }
      flushSegment();
      pendingOp = c;
      continue;
    }
    if (/\s/.test(c)) {
      flushToken();
      continue;
    }
    if (c === "<" || c === ">") {
      flushToken();
      continue;
    }
    current += c;
  }
  flushSegment();
  return segments;
};

export const splitSegments = (command: string): string[][] =>
  splitSegmentsDetailed(command).map((segment) => segment.tokens);

export const isInvocationPosition = (
  tokens: string[],
  index: number,
): boolean => {
  let j = index;
  while (j > 0) {
    const prev = tokens[j - 1];
    if (WRAPPERS.has(prev)) return true;
    if (isFlag(prev) || isNumber(prev) || isAssignment(prev)) {
      j--;
      continue;
    }
    return false;
  }
  return true;
};

export const commandName = (tokens: string[]): string => {
  for (const t of tokens) {
    if (WRAPPERS.has(baseName(t))) continue;
    if (isFlag(t) || isNumber(t) || isAssignment(t)) continue;
    return baseName(t);
  }
  return "";
};
