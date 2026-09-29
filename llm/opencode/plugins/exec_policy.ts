import type { Plugin, PluginInput } from "@opencode-ai/plugin";
import {
  buildDenyRules,
  EMPTY_DENY_RULES,
  findDeniedCommand,
  findExecutionVector,
} from "../lib/exec_policy.ts";
import type { DenyRules } from "../lib/exec_policy.ts";

const isBuildAgent = async (
  client: PluginInput["client"],
  sessionID: string,
): Promise<boolean> => {
  try {
    const { data } = await client.session.get({ path: { id: sessionID } });
    return data?.agent === "build";
  } catch {
    return false;
  }
};

export const ExecPolicyPlugin: Plugin = async ({ client }) => {
  let denyRules: DenyRules = EMPTY_DENY_RULES;

  return {
    config: (cfg) => {
      const sources = cfg as unknown as Record<string, unknown>;
      denyRules = buildDenyRules(sources.permission, sources.agent);
    },

    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;

      const command = String(output.args?.command ?? "");
      const denied = findDeniedCommand(command, denyRules);
      if (denied) {
        throw new Error(
          `${denied} はセキュリティポリシーにより常に拒否されます。実行が必要な場合はユーザーが直接実行してください。`,
        );
      }

      // 任意コード実行(パス実行・インタプリタ・find -exec)は build モードでは
      // jev 判定に委ねる。それ以外のモードではここで即拒否する。
      if (await isBuildAgent(client, input.sessionID)) return;
      const vector = findExecutionVector(command);
      if (vector) {
        throw new Error(
          `${vector} は build モード以外ではセキュリティポリシーにより拒否されます。build エージェントで実行するか、ユーザーが直接実行してください。`,
        );
      }
    },
  };
};
