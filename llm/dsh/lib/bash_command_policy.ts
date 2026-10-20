import { splitSegments } from "../../opencode/lib/shell_parse.ts";

export type BashEffect = "allow" | "deny" | "ask";

export type BashPolicyVerdict = {
  effect: BashEffect;
  matched?: string;
};

const ALLOW_PATTERNS: readonly string[] = [
  "ls *",
  "which*",
  "type*",
  "true",
  "sleep *",
  "grep *",
  "find *",
  "list *",
  "timeout *",
  "cd *",
  "tree *",
  "cat *",
  "head *",
  "wc *",
  "echo *",
  "tail *",
  "sort *",
  "rg *",
  "date *",
  "opencode *",
  "strings *",
  "nix eval *",
  "readlink *",
  "file *",
  "stat *",
  "du *",
  "df *",
  "free *",
  "uptime *",
  "whoami *",
  "id *",
  "sha256sum *",
  "md5sum *",
  "jq *",
  "uniq *",
  "cut *",
  "tr *",
  "sed *",
  "awk *",
  "gawk *",
  "mawk *",
  "curl *",
  "git *",
  "nix flake check *",
  "nix log *",
  "nix build *",
  "nix fmt*",
];

const DENY_PATTERNS: readonly string[] = [
  "xargs *",
  "env *",
  "printenv *",
  "mkdir *",
  "mv *",
  "cp *",
  "touch *",
  "sudo*",
  "eval *",
  "source *",
  ". *",
  "at *",
  "crontab *",
  "opencode run *",
  "rm *",
  "unlink *",
  "chmod *",
  "chown *",
  "chgrp *",
  "install *",
  "dd *",
  "su *",
  "doas *",
  "runuser *",
  "pkexec *",
  "chroot *",
  "unshare *",
  "nsenter *",
  "bwrap *",
  "runc *",
  "crun *",
  "buildah *",
];

type Rule = { pattern: string; effect: BashEffect };

const RULES: readonly Rule[] = [
  ...ALLOW_PATTERNS.map((pattern) => ({ pattern, effect: "allow" as const })),
  ...DENY_PATTERNS.map((pattern) => ({ pattern, effect: "deny" as const })),
];

const literalOf = (pattern: string): string | null =>
  pattern.endsWith("*") ? pattern.slice(0, -1) : null;

const matchesRule = (segment: string, pattern: string): boolean => {
  const literal = literalOf(pattern);
  if (literal === null) return segment === pattern;
  if (literal.endsWith(" ")) {
    return segment === literal.trimEnd() || segment.startsWith(literal);
  }
  return segment.startsWith(literal);
};

const verdictForSegment = (segment: string): BashPolicyVerdict => {
  let best: Rule | undefined;
  for (const rule of RULES) {
    if (!matchesRule(segment, rule.pattern)) continue;
    const bestLiteral = best ? literalOf(best.pattern) : null;
    const ruleLiteral = literalOf(rule.pattern);
    const bestLength = bestLiteral === null ? 0 : bestLiteral.length;
    const ruleLength = ruleLiteral === null ? 0 : ruleLiteral.length;
    if (
      best === undefined ||
      ruleLength > bestLength ||
      (ruleLength === bestLength && rule.effect === "deny")
    ) {
      best = rule;
    }
  }
  if (best === undefined) return { effect: "ask" };
  return { effect: best.effect, matched: best.pattern };
};

export const classifyBashCommand = (command: string): BashPolicyVerdict => {
  const segments = splitSegments(command).map((tokens) => tokens.join(" "));
  if (segments.length === 0) return { effect: "ask" };
  let askedSegment: string | undefined;
  for (const segment of segments) {
    const verdict = verdictForSegment(segment);
    if (verdict.effect === "deny") return verdict;
    if (verdict.effect === "ask" && askedSegment === undefined) {
      askedSegment = segment;
    }
  }
  if (askedSegment === undefined) return { effect: "allow" };
  return { effect: "ask" };
};
