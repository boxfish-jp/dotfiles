#!/usr/bin/env python3
"""Fetch all GitHub PR messages with review-thread resolution state.

Read-only: this script never writes to GitHub and never resolves comments.

Usage:
    python3 scripts/fetch_pr_comments.py OWNER/REPO NUMBER [--out DIR]
                                        [--unresolved-only]

Requires an authenticated `gh` CLI and Python 3.

If `gh` fails because it cannot write its cache, point XDG_CACHE_HOME at a
writable directory before running this script.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path


def run(args):
    try:
        proc = subprocess.run(args, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(f"command failed: {' '.join(args)}\n{exc.stderr}") from exc
    return proc.stdout


def gh_rest_all(path):
    """GET a REST list endpoint with explicit per-page pagination."""
    items = []
    page = 1
    while True:
        sep = "&" if "?" in path else "?"
        raw = run(["gh", "api", f"{path}{sep}per_page=100&page={page}"])
        data = json.loads(raw) if raw.strip() else []
        if not isinstance(data, list) or not data:
            break
        items.extend(data)
        if len(data) < 100:
            break
        page += 1
    return items


QUERY = """
query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100, after: $cursor) {
        totalCount
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          isOutdated
          comments(first: 100) {
            nodes {
              databaseId
              body
              path
              line
              originalLine
              createdAt
              author { login }
            }
          }
        }
      }
    }
  }
}
"""


def gh_graphql(variables):
    args = ["gh", "api", "graphql", "-f", "query=" + QUERY]
    for key, value in variables.items():
        if value is None:
            continue
        flag = "-F" if isinstance(value, int) else "-f"
        args.extend([flag, f"{key}={value}"])
    return json.loads(run(args))


def fetch_threads(owner, repo, number):
    threads = []
    cursor = None
    warnings = []
    while True:
        data = gh_graphql(
            {"owner": owner, "repo": repo, "number": number, "cursor": cursor}
        )
        conn = data["data"]["repository"]["pullRequest"]["reviewThreads"]
        threads.extend(conn["nodes"])
        for node in conn["nodes"]:
            if len(node["comments"]["nodes"]) == 100:
                warnings.append(
                    f"thread {node['id']} hit the 100-comment per-thread limit"
                )
        page = conn["pageInfo"]
        if not page["hasNextPage"]:
            break
        cursor = page["endCursor"]
    return threads, warnings


def normalize_thread(node):
    comments = [
        {
            "id": c["databaseId"],
            "author": (c["author"] or {}).get("login"),
            "createdAt": c["createdAt"],
            "path": c["path"],
            "line": c["line"],
            "originalLine": c["originalLine"],
            "body": c["body"],
        }
        for c in node["comments"]["nodes"]
    ]
    first = comments[0] if comments else {}
    return {
        "id": node["id"],
        "resolved": node["isResolved"],
        "outdated": node["isOutdated"],
        "path": first.get("path"),
        "line": first.get("line"),
        "originalLine": first.get("originalLine"),
        "author": first.get("author"),
        "comments": comments,
    }


def render_markdown(result, unresolved_only):
    counts = result["counts"]
    lines = [
        f"# {result['repository']} PR #{result['pullRequest']} comments",
        "",
        f"- inline comments (REST): {counts['restInlineComments']}",
        f"- inline comments (GraphQL): {counts['graphqlInlineComments']}",
        f"- review threads: {counts['threads']} "
        f"(unresolved {counts['unresolved']}, resolved {counts['resolved']}, "
        f"outdated {counts['outdated']})",
        f"- review bodies: {counts['reviews']}",
        f"- general comments: {counts['issueComments']}",
        "",
    ]
    for warning in result["warnings"]:
        lines.append(f"> WARNING: {warning}")
    if result["warnings"]:
        lines.append("")

    lines.append(
        "## 未解決スレッド" if unresolved_only else "## レビューコメント（スレッド単位）"
    )
    lines.append("")
    found = False
    for thread in result["threads"]:
        if unresolved_only and thread["resolved"]:
            continue
        found = True
        loc = f"{thread['path']}:{thread['line'] or thread['originalLine'] or '-'}"
        lines.append(
            f"### [{thread['id']}] resolved={thread['resolved']} "
            f"outdated={thread['outdated']} {loc} — {thread['author']}"
        )
        for comment in thread["comments"]:
            lines.append(f"- **{comment['author']}** ({comment['createdAt']}):")
            lines.append(comment["body"])
            lines.append("")
    if not found:
        lines.append("(なし)")
        lines.append("")

    lines.append("## レビュー本文")
    lines.append("")
    if result["reviews"]:
        for review in result["reviews"]:
            if not review.get("body"):
                continue
            lines.append(
                f"### [{review['id']}] {review['user']['login']} "
                f"({review['state']}, {review['submitted_at']})"
            )
            lines.append(review["body"])
            lines.append("")
    else:
        lines.append("(なし)")
        lines.append("")

    lines.append("## 一般コメント")
    lines.append("")
    if result["issueComments"]:
        for comment in result["issueComments"]:
            lines.append(
                f"### [{comment['id']}] {comment['user']['login']} "
                f"({comment['created_at']})"
            )
            lines.append(comment["body"])
            lines.append("")
    else:
        lines.append("(なし)")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository", help="OWNER/REPO")
    parser.add_argument("number", type=int, help="PR number")
    parser.add_argument("--out", default=".", help="output directory")
    parser.add_argument("--unresolved-only", action="store_true")
    args = parser.parse_args()

    owner, repo = args.repository.split("/", 1)
    number = args.number

    rest_comments = gh_rest_all(f"repos/{owner}/{repo}/pulls/{number}/comments")
    reviews = gh_rest_all(f"repos/{owner}/{repo}/pulls/{number}/reviews")
    issue_comments = gh_rest_all(f"repos/{owner}/{repo}/issues/{number}/comments")
    thread_nodes, warnings = fetch_threads(owner, repo, number)
    threads = [normalize_thread(node) for node in thread_nodes]

    graphql_ids = {
        c["id"] for thread in threads for c in thread["comments"] if c["id"]
    }
    rest_ids = {c["id"] for c in rest_comments}
    if rest_ids != graphql_ids:
        missing = sorted(rest_ids - graphql_ids)
        extra = sorted(graphql_ids - rest_ids)
        warnings.append(
            f"REST/GraphQL mismatch: rest_only={missing[:10]} "
            f"graphql_only={extra[:10]}"
        )

    result = {
        "repository": args.repository,
        "pullRequest": number,
        "counts": {
            "restInlineComments": len(rest_comments),
            "graphqlInlineComments": len(graphql_ids),
            "threads": len(threads),
            "unresolved": sum(not t["resolved"] for t in threads),
            "resolved": sum(t["resolved"] for t in threads),
            "outdated": sum(t["outdated"] for t in threads),
            "reviews": len(reviews),
            "issueComments": len(issue_comments),
        },
        "warnings": warnings,
        "threads": threads,
        "reviews": reviews,
        "issueComments": issue_comments,
        "restInlineComments": rest_comments,
    }

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = f"{repo}-pr{number}-comments"
    json_path = out_dir / f"{stem}.json"
    md_path = out_dir / f"{stem}.md"
    json_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    md_path.write_text(render_markdown(result, args.unresolved_only), encoding="utf-8")

    print(json.dumps(result["counts"], ensure_ascii=False))
    for warning in warnings:
        print(f"WARNING: {warning}", file=sys.stderr)
    print(json_path)
    print(md_path)


if __name__ == "__main__":
    main()
