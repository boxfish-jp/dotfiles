import type { PluginInput } from "@opencode-ai/plugin";

type OpencodeClient = PluginInput["client"];

type SessionInfo = { agent?: string; parentID?: string };

const PLAN_AGENTS: ReadonlySet<string> = new Set(["plan", "explorer"]);

const MAX_CHAIN_DEPTH = 16;

const fetchSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<SessionInfo | undefined> => {
  try {
    const { data } = await client.session.get({ path: { id: sessionID } });
    return data as SessionInfo | undefined;
  } catch {
    return undefined;
  }
};

export const isPlanSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => {
  const visited = new Set<string>();
  let current: string | undefined = sessionID;
  while (current && !visited.has(current) && visited.size < MAX_CHAIN_DEPTH) {
    visited.add(current);
    const info = await fetchSession(client, current);
    if (info?.agent && PLAN_AGENTS.has(info.agent)) return true;
    current = info?.parentID;
  }
  return false;
};

export const isBuildSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => !(await isPlanSession(client, sessionID));
