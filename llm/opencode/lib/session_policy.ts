import type { PluginInput } from "@opencode-ai/plugin";

type OpencodeClient = PluginInput["client"];

type SessionRecord = { agent?: string; parentID?: string; directory?: string };

const PLAN_AGENTS: ReadonlySet<string> = new Set(["plan", "explorer"]);

const MAX_CHAIN_DEPTH = 16;

export type SessionMode = "plan" | "build";

export type SessionInsight = { mode: SessionMode; directory?: string };

const fetchSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<SessionRecord | undefined> => {
  try {
    const { data } = await client.session.get({ path: { id: sessionID } });
    return data as SessionRecord | undefined;
  } catch {
    return undefined;
  }
};

export const sessionInfo = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<SessionInsight> => {
  const visited = new Set<string>();
  let current: string | undefined = sessionID;
  let mode: SessionMode = "build";
  let directory: string | undefined;
  while (current && !visited.has(current) && visited.size < MAX_CHAIN_DEPTH) {
    visited.add(current);
    const info = await fetchSession(client, current);
    if (info?.agent && PLAN_AGENTS.has(info.agent)) mode = "plan";
    if (directory === undefined && info?.directory) directory = info.directory;
    if (mode === "plan" && directory !== undefined) break;
    current = info?.parentID;
  }
  return { mode, directory };
};

export const isPlanSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => (await sessionInfo(client, sessionID)).mode === "plan";

export const isBuildSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => !(await isPlanSession(client, sessionID));
