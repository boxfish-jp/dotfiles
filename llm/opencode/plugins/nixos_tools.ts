import type { Plugin } from "@opencode-ai/plugin";
import { buildNixHint, findMissingCommand } from "../lib/nixos_hint.ts";

export const NixosToolsPlugin: Plugin = async ({ client }) => {
  const _hinted = new Set<string>();
  return {
    "tool.execute.after": async (input, output) => {
      if (input.tool !== "bash") return;
      const command = findMissingCommand(output.output);
      if (!command) return;
      const key = `${input.sessionID}:${command}`;
      if (_hinted.has(key)) return;
      _hinted.add(key);
      output.output += buildNixHint(command);
      await client.app.log({
        body: {
          service: "NixosToolsPlugin",
          level: "info",
          message: `command not found: ${command}`,
        },
      });
    },
  };
};
