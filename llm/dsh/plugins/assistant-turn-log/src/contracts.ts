/**
 * Structural mirrors of the Harness runtime contracts this plugin touches.
 *
 * They are intentionally local: the bundle has no runtime dependency on
 * `@deepseek-ai/*` packages, so these declarations keep it self-contained.
 * Shapes were verified against the live `Event` and `Service` inspection
 * output of DSH 0.2.0-rc.2.
 */

/** Logger surface used by a plugin context. */
export interface PluginLogger {
  warn(message: string): void;
}

/** The subset of `ctx` this plugin uses. */
export interface PluginContext {
  on(
    event: 'session/event',
    listener: (session: SessionLike, event: SessionEventLike) => void,
  ): () => void;
  on(event: 'session/disposed', listener: (session: SessionLike) => void): () => void;
  effect(initialize: () => () => void | Promise<void>): unknown;
  readonly logger?: PluginLogger;
}

/** Durable header fields read from a live session. */
export interface SessionHeaderLike {
  readonly cwd?: string;
  readonly origin?: 'subagent';
}

/** The live session passed to `session/event`. */
export interface SessionLike {
  readonly id: string;
  readonly header: SessionHeaderLike;
}

/** One content block; only `type` and `text` are read by this plugin. */
export interface ContentBlockLike {
  readonly type: string;
  readonly text?: string;
  readonly [key: string]: unknown;
}

/** Provider metadata of a model-authored message. */
export interface ModelSourceLike {
  readonly kind: 'model';
  readonly provider: string;
  readonly model: string;
}

/** The assistant message stored by `assistant/message`. */
export interface AssistantMessageLike {
  readonly content: readonly ContentBlockLike[];
  readonly source: ModelSourceLike;
}

/** Token counters reported for one model response. */
export interface TokenUsageLike {
  readonly inputTokens?: number;
  readonly outputTokens?: number;
  readonly totalTokens?: number;
  readonly cacheReadTokens?: number;
  readonly cacheWriteTokens?: number;
  readonly reasoningTokens?: number;
}

/** Any session event, narrowed by the type guards below. */
export interface SessionEventLike {
  readonly type: string;
  readonly seq: number;
  readonly time: number;
  readonly data: unknown;
}

/** `assistant/message` payload: one committed model response. */
export interface AssistantMessageEvent extends SessionEventLike {
  readonly type: 'assistant/message';
  readonly data: {
    readonly turn: number;
    readonly step: number;
    readonly message: AssistantMessageLike;
    readonly usage?: TokenUsageLike;
    readonly interrupted?: true;
  };
}

/** `turn/start` payload. */
export interface TurnStartEvent extends SessionEventLike {
  readonly type: 'turn/start';
  readonly data: {
    readonly turn: number;
  };
}

/** `turn/end` payload. The reason is recorded verbatim. */
export interface TurnEndEvent extends SessionEventLike {
  readonly type: 'turn/end';
  readonly data: {
    readonly turn: number;
    readonly reason: unknown;
  };
}

/** Narrow one session event to `assistant/message`. */
export function isAssistantMessageEvent(event: SessionEventLike): event is AssistantMessageEvent {
  return event.type === 'assistant/message';
}

/** Narrow one session event to `turn/start`. */
export function isTurnStartEvent(event: SessionEventLike): event is TurnStartEvent {
  return event.type === 'turn/start';
}

/** Narrow one session event to `turn/end`. */
export function isTurnEndEvent(event: SessionEventLike): event is TurnEndEvent {
  return event.type === 'turn/end';
}

/** Row config accepted by the plugin. All fields are optional. */
export interface PluginConfig {
  /** Absolute JSONL path. Defaults to `$DSH_HOME/assistant-turn-log/turns.jsonl`. */
  readonly outputPath?: string;
  /** Record subagent sessions too. Defaults to `false`. */
  readonly includeSubagents?: boolean;
  /** Record turns whose final assistant message has no text. Defaults to `false`. */
  readonly includeEmpty?: boolean;
  /** Maximum response characters; `0` means unlimited. Defaults to `20000`. */
  readonly maxTextChars?: number;
}
