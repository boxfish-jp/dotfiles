import type { Plugin, PluginInput } from "@opencode-ai/plugin";
import { judgeBashCommand, resolveApiKey } from "../lib/jev_policy.ts";
import type { BashMode, JevVerdict } from "../lib/jev_policy.ts";

type OpencodeClient = PluginInput["client"];

type PermissionAskedProperties = {
  id: string;
  sessionID: string;
  permission: string;
  metadata?: { command?: unknown };
};

const RESPONSE_BY_VERDICT: Record<Exclude<JevVerdict, "human">, "once" | "reject"> = {
  allow: "once",
  reject: "reject",
};

const bashModeOf = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<BashMode> => {
  try {
    const { data } = await client.session.get({ path: { id: sessionID } });
    return data?.agent === "plan" ? "plan" : "build";
  } catch {
    return "build";
  }
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

      const mode = await bashModeOf(client, req.sessionID);
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
      if (verdict === "human") return;

      await client
        .postSessionIdPermissionsPermissionId({
          path: { id: req.sessionID, permissionID: req.id },
          body: { response: RESPONSE_BY_VERDICT[verdict] },
        })
        .catch(() => {});
    },
  };
};
