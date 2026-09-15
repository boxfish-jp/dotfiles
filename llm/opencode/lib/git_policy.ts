import {
  baseName,
  commandName,
  isFlag,
  isInvocationPosition,
  splitSegments,
} from "./shell_parse.ts";

const GIT = "git";

export const READONLY_GIT_SUBCOMMANDS: ReadonlySet<string> = new Set([
  "blame",
  "cat-file",
  "describe",
  "diff",
  "grep",
  "log",
  "ls-files",
  "ls-remote",
  "ls-tree",
  "reflog",
  "rev-parse",
  "shortlog",
  "show",
  "status",
]);

export const WRITE_GIT_SUBCOMMANDS: ReadonlySet<string> = new Set([
  "add",
  "cherry-pick",
  "clone",
  "commit",
  "fetch",
  "init",
  "merge",
  "mv",
  "pull",
  "push",
  "rebase",
  "reset",
  "rm",
  "stash",
]);

export const SOFT_WRITE_GIT_SUBCOMMANDS: ReadonlySet<string> = new Set([
  "add",
  "mv",
]);

const GLOBAL_VALUE_SHORTS = new Set(["-C", "-c"]);

const GLOBAL_VALUE_LONGS = new Set([
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--super-prefix",
]);

const findSubcommandIndex = (tokens: string[], gitIndex: number): number => {
  for (let k = gitIndex + 1; k < tokens.length; k++) {
    const t = tokens[k];
    if (!isFlag(t)) return k;
    if (GLOBAL_VALUE_SHORTS.has(t)) {
      k++;
      continue;
    }
    if (t.includes("=")) continue;
    if (GLOBAL_VALUE_LONGS.has(t)) k++;
  }
  return -1;
};

type ListPolicy = {
  dangerousChars: Set<string>;
  dangerousPrefixes: string[];
  listingChars: Set<string>;
  listingPrefixes: string[];
  valueLongs: Set<string>;
};

const BRANCH_POLICY: ListPolicy = {
  dangerousChars: new Set(["d", "D", "m", "M", "c", "C", "f", "u"]),
  dangerousPrefixes: [
    "--delete",
    "--copy",
    "--move",
    "--edit-description",
    "--set-upstream",
    "--track",
    "--unset-upstream",
    "--force",
  ],
  listingChars: new Set(["a", "r", "l", "v", "i"]),
  listingPrefixes: [
    "--list",
    "--all",
    "--remotes",
    "--verbose",
    "--show-current",
    "--contains",
    "--no-contains",
    "--merged",
    "--no-merged",
    "--points-at",
    "--sort",
    "--format",
    "--color",
    "--column",
    "--ignore-case",
    "--abbrev",
    "--pattern",
    "--no-color",
    "--no-column",
    "--no-abbrev",
  ],
  valueLongs: new Set([
    "--contains",
    "--no-contains",
    "--points-at",
    "--sort",
    "--format",
    "--column",
    "--abbrev",
  ]),
};

const TAG_POLICY: ListPolicy = {
  dangerousChars: new Set(["d", "a", "s", "u", "m", "F", "f", "e"]),
  dangerousPrefixes: [
    "--delete",
    "--annotate",
    "--sign",
    "--local-user",
    "--message",
    "--file",
    "--force",
    "--edit",
    "--cleanup",
    "--create-reflog",
  ],
  listingChars: new Set(["l", "n", "i"]),
  listingPrefixes: [
    "--list",
    "--contains",
    "--no-contains",
    "--merged",
    "--no-merged",
    "--points-at",
    "--sort",
    "--format",
    "--color",
    "--column",
    "--ignore-case",
    "--abbrev",
    "--no-color",
    "--no-column",
    "--no-abbrev",
  ],
  valueLongs: new Set([
    "--contains",
    "--no-contains",
    "--points-at",
    "--sort",
    "--format",
    "--column",
    "--abbrev",
  ]),
};

type ArgValidator = (tokens: string[], startIndex: number) => string | null;

const scanListCommand =
  (policy: ListPolicy): ArgValidator =>
  (tokens, startIndex) => {
    let listingMode = false;
    for (let k = startIndex; k < tokens.length; k++) {
      const t = tokens[k];
      if (t === "--") {
        if (!listingMode) return t;
        continue;
      }
      if (!isFlag(t)) {
        if (!listingMode) return t;
        continue;
      }
      const bare = t.split("=")[0];
      if (policy.dangerousPrefixes.some((p) => bare.startsWith(p))) return t;
      if (!t.startsWith("--")) {
        for (const ch of t.slice(1)) {
          if (policy.dangerousChars.has(ch)) return t;
          if (policy.listingChars.has(ch)) listingMode = true;
        }
        continue;
      }
      const knownLong = policy.listingPrefixes.some(
        (p) => bare === p || bare.startsWith(p),
      );
      if (!knownLong) return t;
      listingMode = true;
      if (!t.includes("=") && policy.valueLongs.has(bare)) k++;
    }
    return null;
  };

const REMOTE_READONLY_VERBS = new Set(["show", "get-url"]);

const scanRemote: ArgValidator = (tokens, startIndex) => {
  let k = startIndex;
  while (k < tokens.length && (tokens[k] === "-v" || tokens[k] === "--verbose")) k++;
  const verb = tokens[k];
  if (verb === undefined || REMOTE_READONLY_VERBS.has(verb)) return null;
  return verb;
};

const CONFIG_WRITE_FLAGS = [
  "--add",
  "--unset",
  "--unset-all",
  "--replace-all",
  "--rename-section",
  "--remove-section",
  "--edit",
];

const CONFIG_VALUE_LONGS = new Set(["--file", "--blob", "--default", "--type"]);

const scanConfig: ArgValidator = (tokens, startIndex) => {
  const positionals: string[] = [];
  for (let k = startIndex; k < tokens.length; k++) {
    const t = tokens[k];
    if (CONFIG_WRITE_FLAGS.some((p) => t.startsWith(p))) return t;
    if (t === "-e") return t;
    if (t === "-f") {
      k++;
      continue;
    }
    if (isFlag(t)) {
      const bare = t.split("=")[0];
      if (!t.includes("=") && CONFIG_VALUE_LONGS.has(bare)) k++;
      continue;
    }
    positionals.push(t);
  }
  return positionals.length >= 2 ? positionals[1] : null;
};

const SUBCOMMAND_VALIDATORS: Record<string, ArgValidator> = {
  branch: scanListCommand(BRANCH_POLICY),
  tag: scanListCommand(TAG_POLICY),
  remote: scanRemote,
  config: scanConfig,
};

export const findForbiddenGitCommand = (command: string): string | null => {
  for (const tokens of splitSegments(command)) {
    for (let i = 0; i < tokens.length; i++) {
      if (baseName(tokens[i]) !== GIT) continue;
      if (!isInvocationPosition(tokens, i)) continue;
      const subIndex = findSubcommandIndex(tokens, i);
      if (subIndex === -1) continue;
      const subcommand = tokens[subIndex];
      const validator = SUBCOMMAND_VALIDATORS[subcommand];
      if (!validator) continue;
      const hit = validator(tokens, subIndex + 1);
      if (hit) return `${GIT} ${subcommand} の ${hit}`;
    }
  }
  return null;
};

const gitSubcommandsOf = (tokens: string[]): string[] => {
  const subs: string[] = [];
  for (let i = 0; i < tokens.length; i++) {
    if (baseName(tokens[i]) !== GIT) continue;
    if (!isInvocationPosition(tokens, i)) continue;
    const subIndex = findSubcommandIndex(tokens, i);
    if (subIndex === -1) continue;
    const sub = tokens[subIndex];
    if (sub !== undefined) subs.push(sub);
  }
  return subs;
};

export const findWriteGitSubcommands = (command: string): string[] => {
  const hits: string[] = [];
  for (const tokens of splitSegments(command)) {
    for (const sub of gitSubcommandsOf(tokens)) {
      if (WRITE_GIT_SUBCOMMANDS.has(sub) && !hits.includes(sub)) hits.push(sub);
    }
  }
  return hits;
};

const isPureGitChain = (
  command: string,
  allowSubcommands: ReadonlySet<string>,
): boolean => {
  const segments = splitSegments(command);
  if (segments.length === 0) return false;
  for (const tokens of segments) {
    if (commandName(tokens) !== GIT) return false;
    const subs = gitSubcommandsOf(tokens);
    if (subs.length === 0) return false;
    if (!subs.every((sub) => allowSubcommands.has(sub))) return false;
  }
  return true;
};

export const isReadOnlyGitChain = (command: string): boolean =>
  isPureGitChain(command, READONLY_GIT_SUBCOMMANDS);

export const isBuildGitChain = (command: string): boolean =>
  isPureGitChain(
    command,
    new Set([...READONLY_GIT_SUBCOMMANDS, ...SOFT_WRITE_GIT_SUBCOMMANDS]),
  );
