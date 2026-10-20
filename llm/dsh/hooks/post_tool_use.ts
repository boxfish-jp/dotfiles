import {
  buildNixHint,
  findMissingCommand,
} from "../../opencode/lib/nixos_hint.ts";
import { emitPostToolContext, readHookPayload } from "../lib/hook_io.ts";

const run = (): void => {
  const payload = readHookPayload();
  if (payload.tool_name !== "bash") return;
  const command = findMissingCommand(String(payload.tool_response ?? ""));
  if (!command) return;
  emitPostToolContext(buildNixHint(command));
};

run();
