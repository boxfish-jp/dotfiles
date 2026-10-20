import {
  findForbiddenGitCommand,
  findWriteGitSubcommands,
  SOFT_WRITE_GIT_SUBCOMMANDS,
} from "../../opencode/lib/git_policy.ts";
import type { JevDecision } from "../../opencode/lib/jev_policy.ts";
import { judgeBashCommand } from "../../opencode/lib/jev_policy.ts";
import { resolveApiKey } from "../../opencode/lib/openrouter_key.ts";
import { collectCommandFacts } from "../../opencode/lib/session_context.ts";
import { classifyBashCommand } from "./bash_command_policy.ts";

export type PreToolDecision = { effect: "deny" | "ask"; reason: string };

type JudgeParams = Parameters<typeof judgeBashCommand>[0];

export type DecideParams = {
  command: string;
  cwd: string;
  apiKey?: string | null;
  fetchImpl?: JudgeParams["fetchImpl"];
};

const gitWritesDecision = (command: string): PreToolDecision | "pass" => {
  const writes = findWriteGitSubcommands(command);
  if (writes.length === 0) return "pass";
  const softOnly = writes.every((sub) => SOFT_WRITE_GIT_SUBCOMMANDS.has(sub));
  if (softOnly) {
    return {
      effect: "ask",
      reason: `git ${writes.join(", ")} はユーザーの確認を要求します。`,
    };
  }
  return {
    effect: "deny",
    reason: `git ${writes.join(", ")} はこのフックにより拒否されます。git の変更操作はユーザーが直接実行してください。`,
  };
};

const decideWithJev = async (
  command: string,
  cwd: string,
  params: DecideParams,
): Promise<PreToolDecision | null> => {
  const apiKey = params.apiKey ?? resolveApiKey();
  if (!apiKey) {
    return {
      effect: "ask",
      reason:
        "jev の判定キーがないため、このコマンドはユーザー確認に委ねられます。",
    };
  }
  const { facts, scriptSections } = collectCommandFacts(command, cwd);
  const decision: JevDecision = await judgeBashCommand({
    command,
    mode: "build",
    apiKey,
    context: { workspaceDir: cwd, facts, scriptSections, recentAllowed: [] },
    fetchImpl: params.fetchImpl,
  });
  if (decision.verdict === "reject") {
    return {
      effect: "deny",
      reason: `jev により拒否されました (source=${decision.source}, confidence=${decision.confidence.toFixed(3)}): ${command}`,
    };
  }
  return null;
};

export const decideBashCommand = async (
  params: DecideParams,
): Promise<PreToolDecision | null> => {
  const { command, cwd } = params;
  if (!command) return null;

  const forbidden = findForbiddenGitCommand(command);
  if (forbidden) {
    return {
      effect: "deny",
      reason: `${forbidden} はモードに関係なく常に拒否されます。破壊的な git 操作はユーザーが直接実行してください。`,
    };
  }

  const gitDecision = gitWritesDecision(command);
  if (gitDecision !== "pass") return gitDecision;

  const verdict = classifyBashCommand(command);
  if (verdict.effect === "deny") {
    return {
      effect: "deny",
      reason: `${verdict.matched ?? "deny"} は bash パーミッションポリシーにより拒否されます。`,
    };
  }
  if (verdict.effect === "allow") return null;

  return decideWithJev(command, cwd, params);
};
