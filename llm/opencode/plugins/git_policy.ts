import type { Plugin, PluginInput } from "@opencode-ai/plugin";
import {
  findForbiddenGitCommand,
  findWriteGitSubcommands,
  isBuildGitChain,
  isReadOnlyGitChain,
  SOFT_WRITE_GIT_SUBCOMMANDS,
} from "../lib/git_policy.ts";

type OpencodeClient = PluginInput["client"];

type PermissionAskedProperties = {
  id: string;
  sessionID: string;
  permission: string;
  metadata?: { command?: unknown };
};

const isBuildAgent = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => {
  try {
    const { data } = await client.session.get({ path: { id: sessionID } });
    return data?.agent === "build";
  } catch {
    return false;
  }
};

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

    const writes = findWriteGitSubcommands(command);
    if (writes.length > 0) {
      const softOnly = writes.every((sub) =>
        SOFT_WRITE_GIT_SUBCOMMANDS.has(sub),
      );
      const buildAllowed =
        softOnly && (await isBuildAgent(client, input.sessionID));
      if (!buildAllowed) {
        throw new Error(
          `git ${writes.join(", ")} はこのプラグインにより拒否されます。git の変更操作は build モードでか、ユーザーが直接実行してください。`,
        );
      }
    }

    await client.app.log({
      body: {
        service: "GitPolicyPlugin",
        level: "info",
        message: `checked bash git policy sessionID=${input.sessionID}`,
      },
    });
  },

  event: async ({ event }) => {
    if (event.type !== "permission.asked") return;
    const req = event.properties as PermissionAskedProperties;
    if (req.permission !== "bash") return;
    const command = String(req.metadata?.command ?? "");
    if (!command.includes("git")) return;
    const passable =
      isReadOnlyGitChain(command) ||
      ((await isBuildAgent(client, req.sessionID)) && isBuildGitChain(command));
    if (!passable) return;
    await client
      .postSessionIdPermissionsPermissionId({
        path: { id: req.sessionID, permissionID: req.id },
        body: { response: "once" },
      })
      .catch(() => {});
  },
});
