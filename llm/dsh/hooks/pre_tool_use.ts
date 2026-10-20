import { decideBashCommand } from "../lib/pre_tool_policy.ts";
import {
  emitPreToolAsk,
  emitPreToolDeny,
  readHookPayload,
} from "../lib/hook_io.ts";

const run = async (): Promise<void> => {
  const payload = readHookPayload();
  if (payload.tool_name !== "bash") return;
  const decision = await decideBashCommand({
    command: String(payload.tool_input?.command ?? ""),
    cwd: String(payload.cwd ?? ""),
  });
  if (!decision) return;
  if (decision.effect === "deny") emitPreToolDeny(decision.reason);
  if (decision.effect === "ask") emitPreToolAsk(decision.reason);
};

await run().catch(() => undefined);
