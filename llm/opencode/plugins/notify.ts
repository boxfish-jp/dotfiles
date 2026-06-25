import type { Plugin } from "@opencode-ai/plugin";

const lastNotified = new Map<string, number>();

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

export const NotifyPlugin: Plugin = async ({ client }) => {
  await client.app.log({
    body: {
      service: "NotifyPlugin",
      level: "info",
      message: "Plugin initialized",
    },
  });
  return {
    event: async ({ event }) => {
      const e = event as { type: string; properties?: Record<string, unknown> };
      if (e.type === "session.idle") {
        notify("completed", "作業が完了しました");
      }
      if (e.type === "permission.asked") {
        const props = e.properties as {
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
        notify("permission", `${detail}の許可を求めています`);
      }
    },
  };
};
