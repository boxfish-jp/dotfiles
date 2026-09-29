import type { Plugin, PluginInput } from "@opencode-ai/plugin";

type OpencodeClient = PluginInput["client"];

const NOTIFY_THROTTLE_MS = 10_000;
const SUMMARY_MIN_LENGTH = 20;
const NOTIFY_CHANNEL = "1";
const NOTIFY_CHARACTER = "3";
const ZEN_API_URL = "https://opencode.ai/zen/v1/chat/completions";
const ZEN_MODEL = "big-pickle";

let apiKey: string | undefined;

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
    .filter(
      (p): p is { type: "text"; text: string } => p.type === "text" && !!p.text,
    )
    .map((p) => p.text)
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

const permissionNotifyWaitMs = () =>
  Number(process.env.OPENCODE_NOTIFY_PERMISSION_WAIT_MS ?? 2_500);

const permissionDetail = (permission?: string): string => {
  switch (permission) {
    case "edit":
      return "編集";
    case "external_directory":
      return "外部フォルダ";
    case "doom_loop":
      return "同じコマンド";
    default:
      return permission ?? "";
  }
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
  client: OpencodeClient,
  text: string,
): Promise<string> => {
  if (text.length <= SUMMARY_MIN_LENGTH) return text;

  if (!apiKey) {
    const { data } = await client.config.providers();
    const provider = data?.providers.find((p) => p.id === "opencode");
    if (!provider?.key) return "ひとことで言えないのだ";
    apiKey = provider.key;
  }

  try {
    const res = await fetch(ZEN_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: ZEN_MODEL,
        messages: [
          {
            role: "user",
            content: `次のテキストを20字以内で語尾に「のだ」を付けた要約文を作成して:\n\n${text}`,
          },
        ],
        reasoning_effort: "low",
      }),
    });

    if (!res.ok) {
      const body = await res.text();
      sendLog(
        client,
        `summarize failed: HTTP ${res.status} ${body.slice(0, 500)}`,
      );
      return "ひとことで言えないのだ";
    }

    const json = await res.json();
    return json.choices?.[0]?.message?.content || "ひとことで言えないのだ";
  } catch (e) {
    sendLog(client, `summarize error: ${e}`);
    return "ひとことで言えないのだ";
  }
};

export const NotifyPlugin: Plugin = async ({
  client,
  directory: _directory,
}) => {
  const notifier = new Notifier();
  const previousState = new Map<string, LogicalState>();
  const pendingPermissionTimers = new Map<
    string,
    ReturnType<typeof setTimeout>
  >();

  const schedulePermissionNotify = (id: string, text: string) => {
    const timer = setTimeout(() => {
      pendingPermissionTimers.delete(id);
      notifier.notify("permission", text);
    }, permissionNotifyWaitMs());
    timer.unref?.();
    pendingPermissionTimers.set(id, timer);
  };

  const cancelPermissionNotify = (id?: string) => {
    if (!id) return;
    const timer = pendingPermissionTimers.get(id);
    if (!timer) return;
    clearTimeout(timer);
    pendingPermissionTimers.delete(id);
  };

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
          const summary = await summarize(client, text);
          sendLog(
            client,
            `summarize took ${((performance.now() - start) / 1000).toFixed(1)}s`,
          );
          notifier.notify("summary", summary);
        }
      }

      if ((event.type as string) === "permission.asked") {
        const props = event.properties as {
          id?: string;
          permission?: string;
        };
        if (props.permission === "question") return;
        let permission = permissionDetail(props.permission);
        if (permission == "bash") {
          permission = "バッシュ";
        }
        const text = `${permission}の許可が欲しいのだ`;
        if (props.permission === "bash" && props.id) {
          schedulePermissionNotify(props.id, text);
          return;
        }
        notifier.notify("permission", text);
      }

      if ((event.type as string) === "permission.replied") {
        const props = event.properties as {
          permissionID?: string;
          requestID?: string;
        };
        cancelPermissionNotify(props.permissionID ?? props.requestID);
      }
    },
    "tool.execute.before": async (input) => {
      if (input.tool !== "question") return;
      if (!(await isParentSession(client, input.sessionID))) return;
      notifier.notify("question", "質問があるのだ");
    },
  };
};
