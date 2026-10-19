import { readFileSync } from "node:fs";

export const resolveApiKey = (
  env: NodeJS.ProcessEnv = process.env,
): string | null => {
  if (env.OPENROUTER_API_KEY) return env.OPENROUTER_API_KEY;
  const dataHome = env.XDG_DATA_HOME ?? `${env.HOME}/.local/share`;
  try {
    const raw = readFileSync(`${dataHome}/opencode/auth.json`, "utf8");
    const auth = JSON.parse(raw) as {
      openrouter?: { type?: string; key?: string };
    };
    if (auth.openrouter?.type === "api" && auth.openrouter.key) {
      return auth.openrouter.key;
    }
  } catch {
    return null;
  }
  return null;
};
