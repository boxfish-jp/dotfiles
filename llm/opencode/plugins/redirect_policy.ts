import type { Plugin } from "@opencode-ai/plugin";
import {
  findEmbeddedExecution,
  findOptionViolations,
  findPipedExecution,
  isRealFileWrite,
} from "../lib/redirect_policy.ts";

const agentBySession = new Map<string, string>();

export const RedirectPolicyPlugin: Plugin = async ({ client }) => ({
  "chat.message": async (input) => {
    if (!input.agent) return;
    agentBySession.set(input.sessionID, input.agent);
  },
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") return;

    const command = String(output.args?.command ?? "");

    const violations = findOptionViolations(command);

    const alwaysViolation = violations.find((v) => v.scope !== "write");
    if (alwaysViolation) {
      throw new Error(
        `${alwaysViolation.description} はセキュリティポリシーにより常に拒否されます。`,
      );
    }

    const piped = findPipedExecution(command);
    if (piped) {
      throw new Error(
        `${piped} はセキュリティポリシーにより常に拒否されます。リモートのスクリプトを取得して直接実行しないでください。`,
      );
    }

    const embedded = findEmbeddedExecution(command);
    if (embedded) {
      throw new Error(
        `${embedded} はセキュリティポリシーにより常に拒否されます。スクリプト内で任意コマンドを実行しないでください。`,
      );
    }

    if (agentBySession.get(input.sessionID) !== "plan") return;

    const writeViolation = violations.find((v) => v.scope === "write");
    if (writeViolation) {
      throw new Error(
        `plan mode では ${writeViolation.description} オプションは許可されません。オプションの順序を入れ替えても拒否されます。ファイル変更が必要な場合は edit ツールを使ってください。`,
      );
    }

    if (isRealFileWrite(command)) {
      throw new Error(
        "plan mode では `>` によるファイル書き込みは許可されません。edit ツールで変更してください。",
      );
    }

    await client.app.log({
      body: {
        service: "RedirectPolicyPlugin",
        level: "info",
        message: `checked bash redirect sessionID=${input.sessionID}`,
      },
    });
  },
});
