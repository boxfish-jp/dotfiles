import type { OpencodeClient, Plugin } from "@opencode-ai/plugin";

const NOTIFY_THROTTLE_MS = 10_000;
const SUMMARY_MIN_LENGTH = 20;
const NOTIFY_CHANNEL = "1";
const NOTIFY_CHARACTER = "3";

type LogicalState = "idle" | "active";

class Notifier {
  private _lastNotified = new Map<string, number>();

  notify = async (key: string, text: string): Promise<void> => {
    const now = Date.now();
    const last = this._lastNotified.get(key) ?? 0;
    if (now - last < NOTIFY_THROTTLE_MS) return;
    this._lastNotified.set(key, now);
    const url = new URL("http://192.168.68.16:50020/");
    url.searchParams.set("text", text);
    url.searchParams.set("channel", NOTIFY_CHANNEL);
    url.searchParams.set("character", NOTIFY_CHARACTER);
    fetch(url, { method: "POST" });
  };
}

const sendLog = (client: OpencodeClient, message: string) =>
  client.app.log({
    body: {
      service: "NotifyPlugin",
      level: "info",
      message,
    },
  });

const extractText = (parts: Array<{ type: string; text?: string }>): string =>
  parts
    .filter((p) => p.type === "text" && p.text)
    .map((p) => p.text!)
    .join("");

const deriveLogicalState = (event: {
  type: string;
  properties: Record<string, unknown>;
}): LogicalState | null => {
  if (event.type === "session.idle") return "idle";
  if (event.type === "session.status") {
    const t = (event.properties as { status?: { type?: string } }).status?.type;
    if (t === "idle") return "idle";
    if (t) return "active";
  }
  return null;
};

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

const summarize = async (
  client: any,
  text: string,
  directory: string,
): Promise<string> => {
  if (text.length <= SUMMARY_MIN_LENGTH) return text;

  const { data: session } = await client.session.create({
    body: { title: "notification summary" },
    query: { directory },
  });
  if (!session) return "ひとことで言えないのだ";

  try {
    const { data: res } = await client.session.prompt({
      path: { id: session.id },
      body: {
        variant: "minimal",
        model: {
          providerID: "opencode",
          modelID: "deepseek-v4-flash-free",
        },
        parts: [
          {
            type: "text",
            text: `次のテキストを20字以内で語尾に「のだ」を付けた要約文を作成して:\n\n${text}`,
          },
        ],
      },
    });
    if (!res) return "ひとことで言えないのだ";

    return extractText(res.parts) || "ひとことで言えないのだ";
  } finally {
    client.session.delete({ path: { id: session.id } });
  }
};

export const NotifyPlugin: Plugin = async ({ client, directory }) => {
  const notifier = new Notifier();
  const previousState = new Map<string, LogicalState>();
  sendLog(client, "Plugin initialized");
  return {
    event: async ({ event }) => {
      const sessionID = (event.properties as { sessionID?: string } | undefined)
        ?.sessionID;

      if (sessionID) {
        const next = deriveLogicalState(event as never);
        if (next) {
          const prev = previousState.get(sessionID);
          previousState.set(sessionID, next);

          if (next !== "idle" || prev === next) return;
          if (!(await isParentSession(client, sessionID))) return; // 子セッションは除外

          notifier.notify("completed", "応答が完了したのだ");
          const { data: msgs } = await client.session.messages({
            path: { id: sessionID },
            query: { limit: 1 },
          });
          const last = msgs?.[msgs.length - 1];
          if (last?.info.role !== "assistant") {
            notifier.notify("completed", "取得に失敗");
            return;
          }
          const text = extractText(last.parts);
          if (!text) return;
          const start = performance.now();
          const summary = await summarize(client, text, directory);
          sendLog(
            client,
            `summarize took ${((performance.now() - start) / 1000).toFixed(1)}s`,
          );
          notifier.notify("summary", summary);
        }
      }

      if ((event.type as string) === "permission.asked") {
        const props = event.properties as {
          permission?: string;
          patterns?: string[];
        };
        let detail = "";
        switch (props.permission) {
          case "edit":
            detail = "編集";
            break;
          case "external_directory":
            detail = "外部フォルダ";
            break;
          case "doom_loop":
            detail = "同じコマンド";
            break;
          default:
            detail = props.permission || "";
        }
        notifier.notify("permission", `${detail}の許可が欲しいのだ`);
      }
    },
  };
};
