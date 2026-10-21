const NOTIFY_CHANNEL = "1";
const NOTIFY_CHARACTER = "3";
const NOTIFY_ENDPOINT = "http://192.168.68.16:50020/";

export const notify = (text: string): void => {
  const url = new URL(NOTIFY_ENDPOINT);
  url.searchParams.set("text", text);
  url.searchParams.set("channel", NOTIFY_CHANNEL);
  url.searchParams.set("character", NOTIFY_CHARACTER);
  void fetch(url, { method: "POST" }).catch(() => undefined);
};
