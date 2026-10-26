import type { Plugin } from "@opencode-ai/plugin";
import type { JevVerdict } from "../lib/jev_policy.ts";
import { judgeBashCommand } from "../lib/jev_policy.ts";
import { resolveApiKey } from "../lib/openrouter_key.ts";
import type { JevContext } from "../lib/session_context.ts";
import {
  collectCommandFacts,
  fetchLatestUserMessage,
} from "../lib/session_context.ts";
import { sessionInfo } from "../lib/session_policy.ts";

type PermissionAskedProperties = {
  id: string;
  sessionID: string;
  permission: string;
  metadata?: { command?: unknown };
};

const RESPONSE_BY_VERDICT: Record<JevVerdict, "once" | "reject"> = {
  allow: "once",
  reject: "reject",
};

const VERDICT_CACHE_LIMIT = 256;
const HISTORY_LIMIT = 10;

const userMessageHash = (text: string): string => {
  let hash = 5381;
  for (let i = 0; i < text.length; i++)
    hash = ((hash * 33) ^ text.charCodeAt(i)) >>> 0;
  return hash.toString(36);
};

const rememberVerdict = (
  cache: Map<string, JevVerdict>,
  key: string,
  verdict: JevVerdict,
): void => {
  cache.set(key, verdict);
  if (cache.size <= VERDICT_CACHE_LIMIT) return;
  const oldest = cache.keys().next().value;
  if (oldest !== undefined) cache.delete(oldest);
};

const rememberAllowed = (
  history: Map<string, string[]>,
  sessionID: string,
  command: string,
): void => {
  const commands = history.get(sessionID) ?? [];
  if (commands[commands.length - 1] === command) return;
  commands.push(command);
  history.set(sessionID, commands.slice(-HISTORY_LIMIT));
};

export const JevPolicyPlugin: Plugin = async ({ client }) => {
  const apiKey = resolveApiKey();
  const verdictByCommand = new Map<string, JevVerdict>();
  const allowedBySession = new Map<string, string[]>();

  return {
    event: async ({ event }) => {
      if (!apiKey || event.type !== "permission.asked") return;
      const req = event.properties as PermissionAskedProperties;
      if (req.permission !== "bash") return;

      const command = String(req.metadata?.command ?? "");
      if (!command) return;

      const [info, userMessage] = await Promise.all([
        sessionInfo(client, req.sessionID),
        fetchLatestUserMessage(client, req.sessionID),
      ]);
      const { facts, scriptSections } = collectCommandFacts(
        command,
        info.directory,
      );
      const context: JevContext = {
        workspaceDir: info.directory,
        facts,
        scriptSections,
        userMessage,
        recentAllowed: allowedBySession.get(req.sessionID) ?? [],
      };

      const cacheKey = `${req.sessionID}:${info.mode}:${command}:${userMessageHash(userMessage ?? "")}`;
      let verdict = verdictByCommand.get(cacheKey);
      if (verdict === undefined) {
        const decision = await judgeBashCommand({
          command,
          mode: info.mode,
          apiKey,
          context,
        });
        verdict = decision.verdict;
        rememberVerdict(verdictByCommand, cacheKey, verdict);
        await client.app.log({
          body: {
            service: "JevPolicyPlugin",
            level: "info",
            message: `jev ${decision.verdict} source=${decision.source} mode=${info.mode} confidence=${decision.confidence.toFixed(3)} probabilities=${JSON.stringify(decision.probabilities ?? {})} cost=$${decision.cost} sessionID=${req.sessionID} command=${command}`,
          },
        });
      }
      if (verdict === "allow") {
        rememberAllowed(allowedBySession, req.sessionID, command);
      }
      await client
        .postSessionIdPermissionsPermissionId({
          path: { id: req.sessionID, permissionID: req.id },
          body: { response: RESPONSE_BY_VERDICT[verdict] },
        })
        .catch(() => {});
    },
  };
};
