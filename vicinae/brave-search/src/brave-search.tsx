import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { useCallback, useEffect, useRef, useState } from "react";
import { Action, ActionPanel, Icon, List, showToast, Toast } from "@vicinae/api";

const SUGGEST_API = "https://search.brave.com/api/suggest";
const SEARCH_URL = "https://search.brave.com/search?q=";
const DEBOUNCE_MS = 300;

const execFileAsync = promisify(execFile);

const searchUrl = (query: string): string => `${SEARCH_URL}${encodeURIComponent(query)}`;

async function fetchSuggestions(query: string): Promise<string[]> {
  const url = `${SUGGEST_API}?source=web&q=${encodeURIComponent(query)}`;
  const { stdout } = await execFileAsync("curl", ["-sS", "--fail", "--max-time", "5", url]);
  const data = JSON.parse(stdout) as [string, string[]];
  return data[1] ?? [];
}

export default function Command() {
  const [query, setQuery] = useState("");
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const requestSeq = useRef(0);

  const handleSearchTextChange = useCallback((text: string) => {
    setQuery(text);
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    const trimmed = text.trim();
    const seq = ++requestSeq.current;

    if (!trimmed) {
      setSuggestions([]);
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    timeoutRef.current = setTimeout(async () => {
      try {
        const results = await fetchSuggestions(trimmed);
        if (seq === requestSeq.current) {
          setSuggestions(results);
        }
      } catch (error) {
        if (seq === requestSeq.current) {
          setSuggestions([]);
          showToast({
            style: Toast.Style.Failure,
            title: "サジェストの取得に失敗しました",
            message: String(error),
          });
        }
      } finally {
        if (seq === requestSeq.current) {
          setIsLoading(false);
        }
      }
    }, DEBOUNCE_MS);
  }, []);

  useEffect(
    () => () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    },
    [],
  );

  const trimmedQuery = query.trim();
  const filteredSuggestions = suggestions.filter((s) => s !== trimmedQuery);

  return (
    <List
      isLoading={isLoading}
      onSearchTextChange={handleSearchTextChange}
      searchBarPlaceholder="Brave で検索..."
    >
      {trimmedQuery && (
        <List.Item
          key={`search:${trimmedQuery}`}
          icon={Icon.MagnifyingGlass}
          title={trimmedQuery}
          subtitle="Brave で検索"
          actions={
            <ActionPanel>
              <Action.OpenInBrowser title="検索" url={searchUrl(trimmedQuery)} />
              <Action.CopyToClipboard title="URLをコピー" content={searchUrl(trimmedQuery)} />
            </ActionPanel>
          }
        />
      )}

      {filteredSuggestions.map((suggestion) => (
        <List.Item
          key={suggestion}
          icon={Icon.Globe01}
          title={suggestion}
          actions={
            <ActionPanel>
              <Action.OpenInBrowser title="検索" url={searchUrl(suggestion)} />
              <Action.CopyToClipboard title="URLをコピー" content={searchUrl(suggestion)} />
            </ActionPanel>
          }
        />
      ))}

      {!trimmedQuery && (
        <List.EmptyView
          icon={{ source: Icon.MagnifyingGlass }}
          title="Brave Search"
          description="検索キーワードを入力するとサジェストが表示されます"
        />
      )}
    </List>
  );
}
