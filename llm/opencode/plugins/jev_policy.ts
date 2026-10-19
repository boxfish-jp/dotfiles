import type { Plugin } from "@opencode-ai/plugin";
import type { JevVerdict } from "../lib/jev_policy.ts";
import { judgeBashCommand } from "../lib/jev_policy.ts";
import { resolveApiKey } from "../lib/openrouter_key.ts";
import { isPlanSession } from "../lib/session_policy.ts";

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

export const JevPolicyPlugin: Plugin = async ({ client }) => {
  const apiKey = resolveApiKey();
  const verdictByCommand = new Map<string, JevVerdict>();

  return {
    event: async ({ event }) => {
      if (!apiKey || event.type !== "permission.asked") return;
      const req = event.properties as PermissionAskedProperties;
      if (req.permission !== "bash") return;

      const command = String(req.metadata?.command ?? "");
      if (!command) return;

      const mode = (await isPlanSession(client, req.sessionID))
        ? "plan"
        : "build";
      const cacheKey = `${mode}:${command}`;
      let verdict = verdictByCommand.get(cacheKey);
      if (verdict === undefined) {
        const decision = await judgeBashCommand({ command, mode, apiKey });
        verdict = decision.verdict;
        verdictByCommand.set(cacheKey, verdict);
        await client.app.log({
          body: {
            service: "JevPolicyPlugin",
            level: "info",
            message: `jev ${verdict} mode=${mode} confidence=${decision.confidence.toFixed(3)} cost=$${decision.cost} sessionID=${req.sessionID} command=${command}`,
          },
        });
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
