import { randomUUID } from "node:crypto";
import type { Part, TextPart } from "@opencode-ai/sdk";
import type { Plugin, PluginInput } from "@opencode-ai/plugin";

type OpencodeClient = PluginInput["client"];

const COMPLETION_RE =
  /(完了|おわった|終わった|終了|できた|やった|完成|仕上げ|レビュー)/;

const hasUserMessage = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => {
  try {
    const { data } = await client.session.messages({
      path: { id: sessionID },
    });
    return data.some((m) => m.info.role === "user");
  } catch {
    return false;
  }
};

const hasStartDirective = (parts: Part[]): boolean =>
  parts.some(
    (p) =>
      p.type === "text" &&
      p.synthetic === true &&
      p.text.includes("todo_start"),
  );

const isParentSession = async (
  client: OpencodeClient,
  sessionID: string,
): Promise<boolean> => {
  try {
    const { data } = await client.session.get({ path: { id: sessionID } });
    return !data?.parentID;
  } catch {
    return true;
  }
};

const buildStartDirective = (isPlan: boolean): string => {
  const planNote = isPlan
    ? " todo_start は todo.org への編集権限を独自に持つため、plan モードでも実行できる。task ツールでのサブエージェント起動はファイル編集ではなく、plan モードの制約に反しない。"
    : "";
  return `【todo管理】このセッションは作業の開始: todo_start サブエージェントを background: true で並行実行しろ。${planNote}メインの推論を止めてはならない。`;
};

const buildCompleteDirective = (isPlan: boolean): string | null =>
  isPlan
    ? null
    : "【todo管理】直前のメッセージは作業完了の報告: todo_done サブエージェントを background: true で並行実行しろ。完了報告を待つな。";

const sendLog = (
  client: OpencodeClient,
  level: "debug" | "info",
  message: string,
) =>
  client.app.log({
    body: {
      service: "TodoAutoPlugin",
      level,
      message,
    },
  });

export const TodoAutoPlugin: Plugin = async ({ client }) => {
  sendLog(client, "info", "Plugin initialized");
  return {
    "chat.message": async (input, output) => {
      if (!(await isParentSession(client, input.sessionID))) return;
      if (hasStartDirective(output.parts)) return;

      const text = output.parts
        .filter(
          (p): p is TextPart =>
            p.type === "text" && !!p.text && !p.synthetic,
        )
        .map((p) => p.text)
        .join("")
        .trim();

      const isPlan = input.agent === "plan";

      let directive: string | null = null;
      if (!(await hasUserMessage(client, input.sessionID))) {
        directive = buildStartDirective(isPlan);
      } else if (text && COMPLETION_RE.test(text)) {
        directive = buildCompleteDirective(isPlan);
      }
      if (!directive) return;

      output.parts.push({
        id: `prt-todo-auto-${randomUUID()}`,
        sessionID: input.sessionID,
        messageID: output.message.id,
        type: "text",
        synthetic: true,
        text: directive,
      });
      await sendLog(client, "debug", "injected todo directive");
    },
  };
};