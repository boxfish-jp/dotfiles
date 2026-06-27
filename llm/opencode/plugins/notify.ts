import type { Plugin } from "@opencode-ai/plugin";

const lastNotified = new Map<string, number>();
const idleTimers = new Map<string, ReturnType<typeof setTimeout>>();
let busy = false;

const notify = async (key: string, text: string) => {
  const now = Date.now();
  const last = lastNotified.get(key) ?? 0;
  if (now - last < 10_000) return;
  lastNotified.set(key, now);
  const url = new URL("http://192.168.68.16:50020/");
  url.searchParams.set("text", text);
  url.searchParams.set("channel", "1");
  url.searchParams.set("character", "3");
  fetch(url, { method: "POST" }).catch(() => {});
};

const cancelIdleTimer = (sessionID: string) => {
  const existing = idleTimers.get(sessionID);
  if (existing) {
    clearTimeout(existing);
    idleTimers.delete(sessionID);
  }
};

const summarize = async (
  client: any,
  text: string,
  directory: string,
): Promise<string> => {
  if (text.length <= 20) return text;

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
        parts: [
          {
            type: "text",
            text: `次のテキストを20字以内で語尾に「のだ」を付けた要約文を作成して:\n\n${text}`,
          },
        ],
      },
    });
    if (!res) return "ひとことで言えないのだ";

    const summary = (res.parts as Array<{ type: string; text?: string }>)
      .filter((p) => p.type === "text" && p.text)
      .map((p) => p.text!)
      .join("");

    return summary || "ひとことで言えないのだ";
  } finally {
    client.session.delete({ path: { id: session.id } }).catch(() => {});
  }
};

export const NotifyPlugin: Plugin = async ({ client, directory }) => {
  await client.app.log({
    body: {
      service: "NotifyPlugin",
      level: "info",
      message: "Plugin initialized",
    },
  });
  return {
    event: async ({ event }) => {
      if (event.type === "session.status") {
        const { sessionID, status } = event.properties;
        if (status.type === "idle") {
          if (busy) return;
          cancelIdleTimer(sessionID);
          idleTimers.set(
            sessionID,
            setTimeout(async () => {
              busy = true;
              try {
                notify("completed", "応答が完了したのだ");
                const { data: msgs } = await client.session.messages({
                  path: { id: sessionID },
                  query: { limit: 1 },
                });
                const last = msgs?.[msgs.length - 1];
                if (last?.info.role === "assistant") {
                  const text = (
                    last.parts as Array<{ type: string; text?: string }>
                  )
                    .filter((p) => p.type === "text" && p.text)
                    .map((p) => p.text!)
                    .join("");
                  if (text) {
                    const start = performance.now();
                    const summary = await summarize(client, text, directory);
                    const elapsed = ((performance.now() - start) / 1000).toFixed(1);
                    client.app.log({
                      body: { service: "NotifyPlugin", level: "info", message: `summarize took ${elapsed}s` },
                    }).catch(() => {});
                    notify("summary", summary);
                    return;
                  }
                }
                notify("completed", "取得に失敗");
              } finally {
                busy = false;
                idleTimers.delete(sessionID);
              }
            }, 3000),
          );
        } else {
          cancelIdleTimer(sessionID);
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
          default:
            detail = props.permission || "";
        }
        notify("permission", `${detail}の許可が欲しいのだ`);
      }
    },
  };
};
