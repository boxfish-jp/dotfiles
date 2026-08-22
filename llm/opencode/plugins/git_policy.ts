import type { Plugin } from "@opencode-ai/plugin";
import { findForbiddenGitCommand } from "../lib/git_policy.ts";

export const GitPolicyPlugin: Plugin = async ({ client }) => ({
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") return;

    const command = String(output.args?.command ?? "");
    const forbidden = findForbiddenGitCommand(command);
    if (forbidden) {
      throw new Error(
        `${forbidden} はモードに関係なく常に拒否されます。破壊的な git 操作はユーザーが直接実行してください。`,
      );
    }

    await client.app.log({
      body: {
        service: "GitPolicyPlugin",
        level: "info",
        message: `checked bash git policy sessionID=${input.sessionID}`,
      },
    });
  },
});
