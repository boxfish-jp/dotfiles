import { userInfo } from "node:os";
import { type LlmRuntime, summarize } from "./llm_summary.js";
import { notify } from "./notify.js";

const DONE_NOTIFICATION = "応答が完了したのだ";
const SUMMARY_FAILURE_NOTIFICATION = "一言で言えないのだ";
const SUMMARY_USERS = new Set(["boxfish", "server"]);

type ContentBlock = {
  readonly type: string;
  readonly text?: string;
};

type Session = {
  readonly id: string;
  readonly header: {
    readonly origin?: "subagent";
  };
};

type SessionEvent = {
  readonly type: string;
};

type AssistantMessageEvent = {
  readonly type: "assistant/message";
  readonly data: {
    readonly turn: number;
    readonly message: {
      readonly content: readonly ContentBlock[];
    };
  };
};

type TurnEndEvent = {
  readonly type: "turn/end";
  readonly data: {
    readonly turn: number;
  };
};

type PluginContext = {
  readonly llm: LlmRuntime;
  on(
    event: "session/event",
    listener: (session: Session, event: SessionEvent) => unknown,
  ): unknown;
  on(event: "session/disposed", listener: (session: Session) => void): unknown;
  on(
    event: "user-questions/request",
    listener: (
      request: unknown,
      next: () => Promise<unknown>,
    ) => Promise<unknown>,
  ): unknown;
  on(
    event: "approval/request",
    listener: (
      request: unknown,
      next: () => Promise<unknown>,
    ) => Promise<unknown>,
  ): unknown;
};

const isAssistantMessageEvent = (
  event: SessionEvent,
): event is AssistantMessageEvent => event.type === "assistant/message";

const isTurnEndEvent = (event: SessionEvent): event is TurnEndEvent =>
  event.type === "turn/end";

const extractTxt = (content: readonly ContentBlock[]): string => {
  const texts: string[] = [];
  for (const block of content) {
    if (block.type !== "text") continue;
    if (block.text === undefined || block.text === "") continue;
    texts.push(block.text);
  }
  return texts.join("\n\n");
};

export const inject = ["llm"];

export const createApply =
  (username: string) =>
  (ctx: PluginContext): void => {
    const summarizeEnabled = SUMMARY_USERS.has(username);
    const pendingBySession = new Map<string, { turn: number; text: string }>();

    ctx.on("session/event", async (session, event) => {
      if (session.header.origin === "subagent") return;
      if (isAssistantMessageEvent(event)) {
        const text = extractTxt(event.data.message.content);
        if (text !== "") {
          pendingBySession.set(session.id, { turn: event.data.turn, text });
        }
        return;
      }
      if (isTurnEndEvent(event)) {
        const pending = pendingBySession.get(session.id);
        pendingBySession.delete(session.id);
        if (pending === undefined || pending.turn !== event.data.turn) {
          return;
        }
        notify(DONE_NOTIFICATION);
        if (!summarizeEnabled) return;
        const summary = await summarize(
          ctx.llm,
          pending.text,
          session.id,
        ).catch(() => undefined);
        notify(summary ?? SUMMARY_FAILURE_NOTIFICATION);
      }
    });

    ctx.on("session/disposed", (session) => {
      pendingBySession.delete(session.id);
    });

    ctx.on("user-questions/request", (_request, next) => {
      notify("質問があるのだ");
      return next();
    });

    ctx.on("approval/request", (_request, next) => {
      notify("許可を求められているのだ");
      return next();
    });
  };

export const apply = createApply(userInfo().username);
