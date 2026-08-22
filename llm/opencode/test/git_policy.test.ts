import { describe, expect, test } from "bun:test";
import { findForbiddenGitCommand } from "../lib/git_policy.ts";

describe("findForbiddenGitCommand", () => {
  describe("git branch", () => {
    test("引数なしの一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch`)).toBeNull();
    });

    test("-aによる全ブランチ一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch -a`)).toBeNull();
    });

    test("-rによるリモートブランチ一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch -r`)).toBeNull();
    });

    test("--show-currentをブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch --show-current`)).toBeNull();
    });

    test("--containsによる一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch --contains HEAD`)).toBeNull();
    });

    test("--mergedによる一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch --merged main`)).toBeNull();
    });

    test("一覧モードでのパターン一致をブロックしない", () => {
      expect(findForbiddenGitCommand(`git branch -a "feature/*"`)).toBeNull();
    });

    test("一覧モード前の位置引数（新規ブランチ作成）をブロックする", () => {
      expect(findForbiddenGitCommand(`git branch feature-x`)).toBe(
        "git branch の feature-x",
      );
    });

    test("-dによるブランチ削除をブロックする", () => {
      expect(findForbiddenGitCommand(`git branch -d feature-x`)).toBe(
        "git branch の -d",
      );
    });

    test("-Dによる強制削除をブロックする", () => {
      expect(findForbiddenGitCommand(`git branch -D main`)).toBe(
        "git branch の -D",
      );
    });

    test("-mによる改名をブロックする", () => {
      expect(findForbiddenGitCommand(`git branch -m old new`)).toBe(
        "git branch の -m",
      );
    });

    test("-fによる強制作成をブロックする", () => {
      expect(findForbiddenGitCommand(`git branch -f x main`)).toBe(
        "git branch の -f",
      );
    });

    test("--set-upstream-to付き作成をブロックする", () => {
      expect(
        findForbiddenGitCommand(`git branch --set-upstream-to=origin/main x`),
      ).toBe("git branch の --set-upstream-to=origin/main");
    });
  });

  describe("git tag", () => {
    test("引数なしの一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git tag`)).toBeNull();
    });

    test("-lパターン一致をブロックしない", () => {
      expect(findForbiddenGitCommand(`git tag -l "v*"`)).toBeNull();
    });

    test("-n5による注釈付き一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git tag -n5`)).toBeNull();
    });

    test("--containsによる一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git tag --contains v1.0`)).toBeNull();
    });

    test("タグ作成をブロックする", () => {
      expect(findForbiddenGitCommand(`git tag v1.0`)).toBe("git tag の v1.0");
    });

    test("-a注釈タグの作成をブロックする", () => {
      expect(findForbiddenGitCommand(`git tag -a v1.0 -m msg`)).toBe(
        "git tag の -a",
      );
    });

    test("-dによるタグ削除をブロックする", () => {
      expect(findForbiddenGitCommand(`git tag -d v1.0`)).toBe("git tag の -d");
    });
  });

  describe("git remote", () => {
    test("引数なしの一覧をブロックしない", () => {
      expect(findForbiddenGitCommand(`git remote`)).toBeNull();
    });

    test("-vをブロックしない", () => {
      expect(findForbiddenGitCommand(`git remote -v`)).toBeNull();
    });

    test("--verboseをブロックしない", () => {
      expect(findForbiddenGitCommand(`git remote --verbose`)).toBeNull();
    });

    test("showによる詳細表示をブロックしない", () => {
      expect(findForbiddenGitCommand(`git remote show origin`)).toBeNull();
    });

    test("get-urlをブロックしない", () => {
      expect(findForbiddenGitCommand(`git remote get-url origin`)).toBeNull();
    });

    test("addをブロックする", () => {
      expect(findForbiddenGitCommand(`git remote add origin url`)).toBe(
        "git remote の add",
      );
    });

    test("set-urlをブロックする", () => {
      expect(findForbiddenGitCommand(`git remote set-url origin new`)).toBe(
        "git remote の set-url",
      );
    });

    test("removeをブロックする", () => {
      expect(findForbiddenGitCommand(`git remote remove origin`)).toBe(
        "git remote の remove",
      );
    });

    test("未知の動詞pruneをブロックする", () => {
      expect(findForbiddenGitCommand(`git remote prune origin`)).toBe(
        "git remote の prune",
      );
    });
  });

  describe("git config", () => {
    test("--listをブロックしない", () => {
      expect(findForbiddenGitCommand(`git config --list`)).toBeNull();
    });

    test("--getによる読み取りをブロックしない", () => {
      expect(findForbiddenGitCommand(`git config --get user.name`)).toBeNull();
    });

    test("単一キーの読み取りをブロックしない", () => {
      expect(findForbiddenGitCommand(`git config user.name`)).toBeNull();
    });

    test("--global付き単一キーの読み取りをブロックしない", () => {
      expect(findForbiddenGitCommand(`git config --global user.name`)).toBeNull();
    });

    test("key value設定をブロックする", () => {
      expect(findForbiddenGitCommand(`git config user.name "John Doe"`)).toBe(
        "git config の John Doe",
      );
    });

    test("--addをブロックする", () => {
      expect(findForbiddenGitCommand(`git config --add user.name x`)).toBe(
        "git config の --add",
      );
    });

    test("--unsetをブロックする", () => {
      expect(findForbiddenGitCommand(`git config --unset user.name`)).toBe(
        "git config の --unset",
      );
    });

    test("--unset-allをブロックできる", () => {
      expect(findForbiddenGitCommand(`git config --unset-all user.name`)).toBe(
        "git config の --unset-all",
      );
    });

    test("-eによるエディタ起動をブロックする", () => {
      expect(findForbiddenGitCommand(`git config -e`)).toBe("git config の -e");
    });
  });

  describe("コマンド位置の解析", () => {
    test("&&でつながった後続位置でも検出できる", () => {
      expect(findForbiddenGitCommand(`echo hi && git branch -D main`)).toBe(
        "git branch の -D",
      );
    });

    test("改行で区切られた後続コマンドも検出できる", () => {
      expect(findForbiddenGitCommand("ls\ngit tag v2")).toBe("git tag の v2");
    });

    test("引用符内のgit branchという文字列は無視する", () => {
      expect(findForbiddenGitCommand(`echo "git branch -D main"`)).toBeNull();
    });

    test("grepの引数に見えるgitは無視する", () => {
      expect(findForbiddenGitCommand(`grep -e git branch notes.txt`)).toBeNull();
    });

    test("gitという語だけのトークンは無視する", () => {
      expect(findForbiddenGitCommand(`printf '%s\\n' git branch`)).toBeNull();
    });

    test("sudo経由のgitを検出できる", () => {
      expect(findForbiddenGitCommand(`sudo git branch -D main`)).toBe(
        "git branch の -D",
      );
    });

    test("フルパス指定のgitを検出できる", () => {
      expect(findForbiddenGitCommand(`/usr/bin/git tag v1`)).toBe(
        "git tag の v1",
      );
    });

    test("グローバルオプション-Cの後でもサブコマンドを特定できる", () => {
      expect(findForbiddenGitCommand(`git -C repo branch -d x`)).toBe(
        "git branch の -d",
      );
    });

    test("グローバルオプション-cの後でもサブコマンドを特定できる", () => {
      expect(
        findForbiddenGitCommand(`git -c core.pager=less branch -D x`),
      ).toBe("git branch の -D");
    });

    test("非対象サブコマンドは無視する", () => {
      expect(findForbiddenGitCommand(`git log --oneline && git status`)).toBeNull();
    });

    test("パイプで区切られた後続コマンドを解析できる", () => {
      expect(findForbiddenGitCommand(`cat f | git remote add o u`)).toBe(
        "git remote の add",
      );
    });
  });
});
