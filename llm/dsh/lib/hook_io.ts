import { readFileSync } from "node:fs";

export type HookPayload = {
  session_id?: string;
  cwd?: string;
  hook_event_name?: string;
  tool_name?: string;
  tool_input?: { command?: unknown };
  tool_use_id?: string;
  tool_response?: string;
};

export const readHookPayload = (): HookPayload =>
  JSON.parse(readFileSync(0, "utf8")) as HookPayload;

const emitJson = (value: unknown): void => {
  process.stdout.write(JSON.stringify(value));
};

export const emitPreToolDeny = (reason: string): void => {
  emitJson({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  });
};

export const emitPreToolAsk = (reason: string): void => {
  emitJson({
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: reason,
    },
  });
};

export const emitPostToolContext = (context: string): void => {
  emitJson({
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: context,
    },
  });
};
