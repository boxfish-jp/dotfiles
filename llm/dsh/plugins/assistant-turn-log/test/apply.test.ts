import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import type {
  AssistantMessageEvent,
  ContentBlockLike,
  PluginContext,
  SessionLike,
  TurnEndEvent,
} from '../src/contracts.js';
import { apply, name } from '../dist/index.js';

let clock = 1_000;

/** One decoded JSONL line, mirroring the plugin's record shape. */
interface RecordedTurn {
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
  usage: Record<string, number> | null;
  responseChars: number;
  truncated: boolean;
  response: string;
}

/** Build one `assistant/message` session event. */
function assistantEvent(
  turn: number,
  step: number,
  text: string,
  options: { toolCalls?: number; interrupted?: boolean } = {},
): AssistantMessageEvent {
  const content: ContentBlockLike[] = [];
  if (text !== '') content.push({ type: 'text', text });
  for (let index = 0; index < (options.toolCalls ?? 0); index += 1) {
    content.push({ type: 'tool-call', id: `call-${index}`, name: 'bash', arguments: '{}' });
  }
  clock += 1;
  return {
    type: 'assistant/message',
    seq: clock,
    time: clock,
    data: {
      turn,
      step,
      message: {
        content,
        source: { kind: 'model', provider: 'test-provider', model: 'test-model' },
      },
      usage: { inputTokens: 10, outputTokens: 5 },
      ...(options.interrupted === true ? { interrupted: true } : {}),
    },
  };
}

/** Build one `turn/end` session event. */
function turnEndEvent(turn: number, reason: unknown = { kind: 'completed' }): TurnEndEvent {
  clock += 1;
  return { type: 'turn/end', seq: clock, time: clock, data: { turn, reason } };
}

/** Minimal Cordis context double: listener capture, effect collection, warn capture. */
function createHarness(): {
  ctx: PluginContext;
  warnings: string[];
  emit(event: string, ...args: unknown[]): void;
  dispose(): Promise<void>;
} {
  const listeners = new Map<string, Array<(...args: unknown[]) => void>>();
  const disposers: Array<() => void | Promise<void>> = [];
  const warnings: string[] = [];
  const ctx = {
    on(event: string, callback: (...args: unknown[]) => void): () => void {
      const list = listeners.get(event) ?? [];
      list.push(callback);
      listeners.set(event, list);
      return () => {};
    },
    effect(initialize: () => () => void | Promise<void>): void {
      disposers.push(initialize());
    },
    logger: {
      warn(message: string): void {
        warnings.push(String(message));
      },
    },
  } as unknown as PluginContext;
  return {
    ctx,
    warnings,
    emit(event, ...args) {
      for (const callback of listeners.get(event) ?? []) callback(...args);
    },
    async dispose() {
      for (const disposer of disposers) await disposer();
    },
  };
}

/** Build one live-session double. */
function session(id = 'session-1', origin?: 'subagent'): SessionLike {
  return {
    id,
    header: { cwd: '/tmp/work', ...(origin === undefined ? {} : { origin }) },
  };
}

/** Run against a temporary directory and always clean it up. */
async function withTempDir(run: (dir: string) => Promise<void>): Promise<void> {
  const dir = await mkdtemp(join(tmpdir(), 'assistant-turn-log-'));
  try {
    await run(dir);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

/** Read and parse every JSONL record; a missing file means no records. */
async function readRecords(file: string): Promise<RecordedTurn[]> {
  let text: string;
  try {
    text = await readFile(file, 'utf8');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw error;
  }
  return text.split('\n').filter(Boolean).map((line) => JSON.parse(line) as RecordedTurn);
}

test('exports the plugin name', () => {
  assert.equal(name, 'assistant-turn-log');
});

test('records the final assistant text and metadata at turn end', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file });
    const main = session();

    harness.emit('session/event', main, assistantEvent(1, 1, 'let me check'));
    harness.emit('session/event', main, assistantEvent(1, 2, 'final answer', { toolCalls: 2 }));
    harness.emit('session/event', main, turnEndEvent(1));
    await harness.dispose();

    const records = await readRecords(file);
    assert.equal(records.length, 1);
    const record = records[0]!;
    assert.equal(record.sessionId, 'session-1');
    assert.equal(record.turn, 1);
    assert.deepEqual(record.reason, { kind: 'completed' });
    assert.equal(record.response, 'final answer');
    assert.equal(record.provider, 'test-provider');
    assert.equal(record.model, 'test-model');
    assert.equal(record.interrupted, false);
    assert.equal(record.assistantMessages, 2);
    assert.equal(record.toolCalls, 2);
    assert.deepEqual(record.usage, { inputTokens: 20, outputTokens: 10 });
    assert.equal(record.responseChars, 'final answer'.length);
    assert.equal(record.truncated, false);
    assert.equal(record.cwd, '/tmp/work');
  });
});

test('skips subagent sessions by default', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file });
    const child = session('child-session', 'subagent');

    harness.emit('session/event', child, assistantEvent(1, 1, 'child answer'));
    harness.emit('session/event', child, turnEndEvent(1));
    await harness.dispose();

    assert.deepEqual(await readRecords(file), []);
  });
});

test('records subagent sessions when enabled', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file, includeSubagents: true });
    const child = session('child-session', 'subagent');

    harness.emit('session/event', child, assistantEvent(1, 1, 'child answer'));
    harness.emit('session/event', child, turnEndEvent(1));
    await harness.dispose();

    const records = await readRecords(file);
    assert.equal(records.length, 1);
    assert.equal(records[0]!.response, 'child answer');
  });
});

test('keeps the turn-end reason for aborted turns', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file });
    const main = session();

    harness.emit('session/event', main, assistantEvent(1, 1, 'partial', { interrupted: true }));
    harness.emit('session/event', main, turnEndEvent(1, { kind: 'aborted', reason: { kind: 'user' } }));
    await harness.dispose();

    const records = await readRecords(file);
    assert.equal(records.length, 1);
    assert.equal(records[0]!.response, 'partial');
    assert.equal(records[0]!.interrupted, true);
    assert.deepEqual(records[0]!.reason, { kind: 'aborted', reason: { kind: 'user' } });
  });
});

test('skips turns without text unless includeEmpty is enabled', async () => {
  await withTempDir(async (dir) => {
    const skipped = join(dir, 'skipped.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: skipped });
    const main = session();

    harness.emit('session/event', main, assistantEvent(1, 1, ''));
    harness.emit('session/event', main, turnEndEvent(1));
    await harness.dispose();
    assert.deepEqual(await readRecords(skipped), []);

    const empty = join(dir, 'empty.jsonl');
    const second = createHarness();
    apply(second.ctx, { outputPath: empty, includeEmpty: true });
    second.emit('session/event', main, assistantEvent(1, 1, ''));
    second.emit('session/event', main, turnEndEvent(1));
    await second.dispose();

    const records = await readRecords(empty);
    assert.equal(records.length, 1);
    assert.equal(records[0]!.response, '');
    assert.equal(records[0]!.assistantMessages, 1);
  });
});

test('appends turns in order', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file });
    const main = session();

    for (const turn of [1, 2]) {
      harness.emit('session/event', main, assistantEvent(turn, 1, `answer ${turn}`));
      harness.emit('session/event', main, turnEndEvent(turn));
    }
    await harness.dispose();

    const records = await readRecords(file);
    assert.deepEqual(records.map((record) => record.turn), [1, 2]);
    assert.deepEqual(records.map((record) => record.response), ['answer 1', 'answer 2']);
  });
});

test('does not reuse text from a different turn', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file });
    const main = session();

    harness.emit('session/event', main, assistantEvent(2, 1, 'turn two'));
    harness.emit('session/event', main, turnEndEvent(1));
    await harness.dispose();

    assert.deepEqual(await readRecords(file), []);
  });
});

test('truncates the response at maxTextChars', async () => {
  await withTempDir(async (dir) => {
    const file = join(dir, 'turns.jsonl');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: file, maxTextChars: 5 });
    const main = session();

    harness.emit('session/event', main, assistantEvent(1, 1, 'abcdefghijkl'));
    harness.emit('session/event', main, turnEndEvent(1));
    await harness.dispose();

    const records = await readRecords(file);
    assert.equal(records.length, 1);
    assert.equal(records[0]!.response, 'abcde…[truncated]');
    assert.equal(records[0]!.responseChars, 12);
    assert.equal(records[0]!.truncated, true);
  });
});

test('defaults under $DSH_HOME/assistant-turn-log/turns.jsonl', async () => {
  await withTempDir(async (dir) => {
    const previous = process.env.DSH_HOME;
    process.env.DSH_HOME = dir;
    try {
      const harness = createHarness();
      apply(harness.ctx, {});
      const main = session();
      harness.emit('session/event', main, assistantEvent(1, 1, 'home answer'));
      harness.emit('session/event', main, turnEndEvent(1));
      await harness.dispose();

      const records = await readRecords(join(dir, 'assistant-turn-log', 'turns.jsonl'));
      assert.equal(records.length, 1);
      assert.equal(records[0]!.response, 'home answer');
    } finally {
      if (previous === undefined) delete process.env.DSH_HOME;
      else process.env.DSH_HOME = previous;
    }
  });
});

test('logs a warning instead of throwing when the write fails', async () => {
  await withTempDir(async (dir) => {
    const blocker = join(dir, 'blocker');
    await writeFile(blocker, 'not a directory');
    const harness = createHarness();
    apply(harness.ctx, { outputPath: join(blocker, 'turns.jsonl') });
    const main = session();

    harness.emit('session/event', main, assistantEvent(1, 1, 'answer'));
    harness.emit('session/event', main, turnEndEvent(1));
    await harness.dispose();

    assert.equal(harness.warnings.length, 1);
    assert.match(harness.warnings[0]!, /failed to append/);
  });
});
