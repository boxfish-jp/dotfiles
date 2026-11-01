export type SubagentRunRef = {
  readonly runId: string;
};

export type TrackableAgent = {
  readonly session: {
    readonly id: string;
  };
  readonly ctx: {
    on(
      event: "subagent/start",
      listener: (run: SubagentRunRef) => unknown,
    ): () => void;
    on(
      event: "subagent/end",
      listener: (run: SubagentRunRef) => unknown,
    ): () => void;
  };
};

type TrackedAgent = {
  readonly agent: TrackableAgent;
  readonly runIds: Set<string>;
};

export const createSubagentRunTracker = () => {
  const trackedBySession = new Map<string, TrackedAgent>();

  const attach = (agent: TrackableAgent): void => {
    const runIds = new Set<string>();
    trackedBySession.set(agent.session.id, { agent, runIds });
    agent.ctx.on("subagent/start", ({ runId }) => {
      runIds.add(runId);
    });
    agent.ctx.on("subagent/end", ({ runId }) => {
      runIds.delete(runId);
    });
  };

  const detach = (agent: TrackableAgent): boolean => {
    if (trackedBySession.get(agent.session.id)?.agent !== agent) return false;
    trackedBySession.delete(agent.session.id);
    return true;
  };

  const clear = (sessionId: string): void => {
    trackedBySession.delete(sessionId);
  };

  const hasActive = (sessionId: string): boolean =>
    (trackedBySession.get(sessionId)?.runIds.size ?? 0) > 0;

  return { attach, detach, clear, hasActive };
};
