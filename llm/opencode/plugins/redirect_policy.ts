import type { Plugin } from "@opencode-ai/plugin";

const REDIRECTS = />\s*([^\s|;&]+)/g;

const isRealFileWrite = (command: string): boolean => {
  for (const match of command.matchAll(REDIRECTS)) {
    const target = match[1];
    if (target.startsWith("/dev/null")) continue;
    if (/^&?\d+$/.test(target)) continue;
    return true;
  }
  return false;
};

const agentBySession = new Map<string, string>();

export const RedirectPolicyPlugin: Plugin = async ({ client }) => ({
  "chat.message": async (input) => {
    if (!input.agent) return;
    agentBySession.set(input.sessionID, input.agent);
  },
  "tool.execute.before": async (input, output) => {
    if (input.tool !== "bash") return;
    if (agentBySession.get(input.sessionID) !== "plan") return;

    const command = String(output.args?.command ?? "");
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
