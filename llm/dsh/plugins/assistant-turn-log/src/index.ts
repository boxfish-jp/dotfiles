/**
 * Host plugin: append one JSONL record for every completed assistant turn.
 *
 * The trigger is the durable `turn/end` session event delivered by
 * `session/event`. The final assistant text is folded from
 * `assistant/message` events in memory because synchronous session-log reads
 * are deprecated for new code.
 *
 * Output path precedence:
 * 1. `config.outputPath`
 * 2. `$DSH_HOME/assistant-turn-log/turns.jsonl`
 * 3. `~/.dsh/assistant-turn-log/turns.jsonl`
 */
import { appendFile, mkdir } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import {
  isAssistantMessageEvent,
  isTurnEndEvent,
  isTurnStartEvent,
  type AssistantMessageEvent,
  type ContentBlockLike,
  type PluginConfig,
  type PluginContext,
  type TokenUsageLike,
} from './contracts.js';

/** Cordis plugin name. */
export const name = 'assistant-turn-log';

/** Default cap for the recorded response text. */
const DEFAULT_MAX_TEXT_CHARS = 20_000;

/** Marker appended when the response text is clipped. */
const TRUNCATION_MARKER = '…[truncated]';

/** Token counters summed across one turn. */
const USAGE_KEYS: readonly (keyof TokenUsageLike)[] = [
  'inputTokens',
  'outputTokens',
  'totalTokens',
  'cacheReadTokens',
  'cacheWriteTokens',
  'reasoningTokens',
];

/** Summed token counters; absent counters stay absent. */
type UsageTotals = Record<string, number>;

/** Per-session fold of the turn currently in flight. */
interface TurnState {
  turn: number;
  text: string;
  provider: string | null;
  model: string | null;
  usage: UsageTotals | null;
  assistantMessages: number;
  toolCalls: number;
  interrupted: boolean;
}

/** One JSONL line written at `turn/end`. */
interface TurnRecord {
  time: number;
  sessionId: string;
  turn: number;
  seq: number;
  reason: unknown;
  cwd: string | null;
  provider: string | null;
  model: string | null;
  interrupted: boolean;
  assistantMessages: number;
  toolCalls: number;
  usage: UsageTotals | null;
  responseChars: number;
  truncated: boolean;
  response: string;
}

/** Resolve the output path, following the harness home resolution. */
function resolveOutputPath(config: PluginConfig): string {
  const configured = config.outputPath;
  if (typeof configured === 'string' && configured.trim() !== '') return configured.trim();
  const home = (process.env.DSH_HOME ?? '').trim() || join(homedir(), '.dsh');
  return join(home, 'assistant-turn-log', 'turns.jsonl');
}

/** Join every text block of one assistant message. */
function textOf(content: readonly ContentBlockLike[]): string {
  let text = '';
  for (const block of content) {
    if (block.type !== 'text') continue;
    const value = block.text;
    if (value === undefined || value === '') continue;
    text = text === '' ? value : `${text}\n\n${value}`;
  }
  return text;
}

/** Count tool-call blocks in one assistant message. */
function toolCallCount(content: readonly ContentBlockLike[]): number {
  let count = 0;
  for (const block of content) if (block.type === 'tool-call') count += 1;
  return count;
}

/** Add one message's usage to the turn total, ignoring absent counters. */
function addUsage(total: UsageTotals | null, usage: TokenUsageLike | undefined): UsageTotals | null {
  if (usage === undefined) return total;
  let next = total;
  for (const key of USAGE_KEYS) {
    const value = usage[key];
    if (typeof value !== 'number' || !Number.isFinite(value)) continue;
    if (next === null) next = {};
    next[key] = (next[key] ?? 0) + value;
  }
  return next;
}

/** Fold one `assistant/message` event into the per-session turn state. */
function fold(state: TurnState | undefined, event: AssistantMessageEvent): TurnState {
  const { turn } = event.data;
  const next: TurnState = state !== undefined && state.turn === turn
    ? state
    : {
      turn,
      text: '',
      provider: null,
      model: null,
      usage: null,
      assistantMessages: 0,
      toolCalls: 0,
      interrupted: false,
    };
  const { message } = event.data;
  const text = textOf(message.content);
  next.assistantMessages += 1;
  next.toolCalls += toolCallCount(message.content);
  if (text !== '') next.text = text;
  next.provider = message.source.provider;
  next.model = message.source.model;
  if (event.data.interrupted === true) next.interrupted = true;
  next.usage = addUsage(next.usage, event.data.usage);
  return next;
}

/** Clip the response text at the configured budget. */
function truncate(text: string, maxChars: number): { text: string; truncated: boolean } {
  if (maxChars <= 0 || text.length <= maxChars) return { text, truncated: false };
  return { text: `${text.slice(0, maxChars)}${TRUNCATION_MARKER}`, truncated: true };
}

/**
 * Register the turn-end listener and the serialized append queue.
 * @param ctx - plugin context.
 * @param config - row config (`outputPath`, `includeSubagents`, `includeEmpty`, `maxTextChars`).
 */
export function apply(ctx: PluginContext, config: PluginConfig = {}): void {
  const outputPath = resolveOutputPath(config);
  const includeSubagents = config.includeSubagents === true;
  const includeEmpty = config.includeEmpty === true;
  const configuredMax = config.maxTextChars;
  const maxTextChars = typeof configuredMax === 'number'
    && Number.isFinite(configuredMax)
    && configuredMax >= 0
    ? configuredMax
    : DEFAULT_MAX_TEXT_CHARS;

  /** Per-session fold of the current turn: a derived cache, cleared at every boundary. */
  const pending = new Map<string, TurnState>();
  let queue: Promise<void> = Promise.resolve();

  const append = (record: TurnRecord): void => {
    queue = queue.then(async () => {
      await mkdir(dirname(outputPath), { recursive: true, mode: 0o700 });
      await appendFile(outputPath, `${JSON.stringify(record)}\n`, { encoding: 'utf8', mode: 0o600 });
    }).catch((error: unknown) => {
      ctx.logger?.warn(`assistant-turn-log: failed to append ${outputPath}: ${String(error)}`);
    });
  };

  ctx.on('session/event', (session, event) => {
    if (isAssistantMessageEvent(event)) {
      pending.set(session.id, fold(pending.get(session.id), event));
      return;
    }
    if (isTurnStartEvent(event)) {
      pending.delete(session.id);
      return;
    }
    if (!isTurnEndEvent(event)) return;

    const folded = pending.get(session.id);
    pending.delete(session.id);
    if (!includeSubagents && session.header.origin === 'subagent') return;
    const state = folded !== undefined && folded.turn === event.data.turn ? folded : undefined;
    const raw = state?.text ?? '';
    if (raw === '' && !includeEmpty) return;
    const clipped = truncate(raw, maxTextChars);
    append({
      time: event.time,
      sessionId: session.id,
      turn: event.data.turn,
      seq: event.seq,
      reason: event.data.reason,
      cwd: typeof session.header.cwd === 'string' ? session.header.cwd : null,
      provider: state?.provider ?? null,
      model: state?.model ?? null,
      interrupted: state?.interrupted === true,
      assistantMessages: state?.assistantMessages ?? 0,
      toolCalls: state?.toolCalls ?? 0,
      usage: state?.usage ?? null,
      responseChars: raw.length,
      truncated: clipped.truncated,
      response: clipped.text,
    });
  });

  ctx.on('session/disposed', (session) => {
    pending.delete(session.id);
  });

  ctx.effect(() => async () => {
    await queue;
  });
}
