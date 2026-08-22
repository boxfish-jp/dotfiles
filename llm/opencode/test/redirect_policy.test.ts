import { describe, expect, test } from "bun:test";
import {
  findEmbeddedExecution,
  findOptionViolations,
  findPipedExecution,
  isRealFileWrite,
} from "../lib/redirect_policy.ts";

const scopesOf = (command: string) =>
  findOptionViolations(command).map((v) => v.scope);

const descriptionsOf = (command: string) =>
  findOptionViolations(command).map((v) => v.description);

describe("findOptionViolations", () => {
  describe("exec系オプションの検出", () => {
    test("awkの-lをexecスコープで検出する", () => {
      expect(findOptionViolations(`awk -l ./evil.so 'BEGIN{}'`)).toEqual([
        { description: "awk の -l", scope: "exec" },
      ]);
    });

    test("awkの--loadをexecスコープで検出する", () => {
      expect(scopesOf(`awk -v x=1 --load evil.so 'BEGIN{}'`)).toEqual([
        "exec",
      ]);
    });

    test("awkの省略接頭辞--loをexecスコープで検出できる", () => {
      expect(
        findOptionViolations(`find . | xargs awk '--loa=/tmp/e.so'`),
      ).toEqual([{ description: "awk の --loa=/tmp/e.so", scope: "exec" }]);
    });

    test("awkの-iによる拡張読み込みをexecスコープで検出する", () => {
      expect(findOptionViolations(`awk -i inplace '{gsub(/a/,"b")}1' f`)).toEqual(
        [{ description: "awk の -i", scope: "exec" }],
      );
    });

    test("awkの--includeをexecスコープで検出する", () => {
      expect(scopesOf(`awk --include inplace '{print}' f`)).toEqual(["exec"]);
    });

    test("gawkのフルパス指定でもexec系を検出できる", () => {
      expect(scopesOf(`/usr/bin/gawk -l ./evil.so 'BEGIN{}'`)).toEqual([
        "exec",
      ]);
    });

    test("timeout経由のawkでもexec系を検出できる", () => {
      expect(scopesOf(`timeout 5 awk -l evil.so 'BEGIN{}'`)).toEqual(["exec"]);
    });

    test("安全フラグの後ろに置いた--loadも検出する", () => {
      expect(scopesOf(`awk -v x=1 --load evil.so 'BEGIN{}'`)).toEqual([
        "exec",
      ]);
    });
  });

  describe("write系オプションの検出", () => {
    test("sedの-iをwriteスコープで検出する", () => {
      expect(findOptionViolations(`sed -e 's/a/b/' -i file.txt`)).toEqual([
        { description: "sed の -i", scope: "write" },
      ]);
    });

    test("sedの値結合形式-i.bakをwriteスコープで検出する", () => {
      expect(findOptionViolations(`sed 's/a/b/' -i.bak file.txt`)).toEqual([
        { description: "sed の -i.bak", scope: "write" },
      ]);
    });

    test("sedの--in-placeをwriteスコープで検出する", () => {
      expect(scopesOf(`sed --in-place 's/a/b/' f`)).toEqual(["write"]);
    });

    test("awkの-oをwriteスコープで検出する", () => {
      expect(scopesOf(`awk '{print}' -o out.txt input.txt`)).toEqual([
        "write",
      ]);
    });

    test("awkの-pをwriteスコープで検出する", () => {
      expect(scopesOf(`timeout 5 awk -p f 'BEGIN{}'`)).toEqual(["write"]);
    });

    test("awkの-dによる変数ダンプをwriteスコープで検出する", () => {
      expect(scopesOf(`awk -d 'BEGIN{}' f`)).toEqual(["write"]);
    });

    test("awkの-gによるpotファイル生成をwriteスコープで検出する", () => {
      expect(scopesOf(`awk -g 'BEGIN{}' f`)).toEqual(["write"]);
    });

    test("awkの--profile=結合形式をwriteスコープで検出する", () => {
      expect(descriptionsOf(`echo foo && awk --profile=x 'BEGIN{}'`)).toContain(
        "awk の --profile=x",
      );
    });

    test("awkの--pretty-printの省略形--preをwriteスコープで検出する", () => {
      expect(scopesOf(`awk -F, '{print $1}' --prof x`)).toEqual(["write"]);
    });

    test("awkの--dump-variablesをwriteスコープで検出する", () => {
      expect(scopesOf("ls\nawk --dump-variables 'BEGIN{}'")).toEqual([
        "write",
      ]);
    });

    test("awkの--gen-potをwriteスコープで検出する", () => {
      expect(scopesOf(`(awk --gen-pot 'BEGIN{}')`)).toEqual(["write"]);
    });
  });

  describe("-W経由の長系オプションの検出", () => {
    test("awk -W profile=fをwriteスコープで検出する", () => {
      expect(findOptionViolations(`awk -W profile=f 'BEGIN{}'`)).toEqual([
        { description: "awk の -W profile=f", scope: "write" },
      ]);
    });

    test("awk -W load=e.soをexecスコープで検出する", () => {
      expect(scopesOf(`awk -W load=evil.so 'BEGIN{}'`)).toEqual(["exec"]);
    });

    test("awk -Wload=e.soの結合形式をexecスコープで検出する", () => {
      expect(scopesOf(`awk -Wload=evil.so 'BEGIN{}'`)).toEqual(["exec"]);
    });
  });

  describe("alwaysスコープの検出", () => {
    test("curlの-oをalwaysスコープで検出する", () => {
      expect(findOptionViolations(`curl https://example.com -o install.sh`)).toEqual(
        [{ description: "curl の -o", scope: "always" }],
      );
    });

    test("curlの-Oをalwaysスコープで検出する", () => {
      expect(scopesOf(`curl -O https://example.com/a.tar.gz`)).toEqual([
        "always",
      ]);
    });

    test("curlの--outputをalwaysスコープで検出する", () => {
      expect(scopesOf(`curl --output install.sh URL`)).toEqual(["always"]);
    });

    test("curlの--output-dirをalwaysスコープで検出する", () => {
      expect(scopesOf(`curl --output-dir /tmp URL`)).toEqual(["always"]);
    });

    test("curlの--remote-nameをalwaysスコープで検出する", () => {
      expect(scopesOf(`curl --remote-name URL`)).toEqual(["always"]);
    });

    test("セグメント後方に置いた-oもalwaysで検出する", () => {
      expect(scopesOf(`printf 'x\\n' | curl -sS URL -o f`)).toEqual([
        "always",
      ]);
    });

    test("クラスタ-sSLoのoをalwaysで検出する", () => {
      expect(descriptionsOf(`curl -sSLo f URL`)).toContain("curl の -sSLo");
    });

    test("値結合形式-oinstall.shをalwaysで検出する", () => {
      expect(scopesOf(`curl -oinstall.sh https://example.com`)).toEqual([
        "always",
      ]);
    });
  });

  describe("誤検知しないケース", () => {
    test("引用符内のawkという文字列は無視する", () => {
      expect(
        findOptionViolations(`echo "awk -o /etc/passwd" | grep oops`),
      ).toEqual([]);
    });

    test("grepの引数に見えるawkは無視する", () => {
      expect(
        findOptionViolations(`grep -e awk --load=evil.so notes.txt`),
      ).toEqual([]);
    });

    test("awkという語だけのトークンは無視する", () => {
      expect(findOptionViolations(`printf '%s\\n' awk sed`)).toEqual([]);
    });

    test("実行位置でないcurlは無視する", () => {
      expect(findOptionViolations(`man curl -o /dev/null`)).toEqual([]);
    });

    test("URLに含まれる-oという綴りは無視する", () => {
      expect(findOptionViolations(`curl https://example.com/-o/info`)).toEqual(
        [],
      );
    });

    test("消費クラスタ-boの-oは-bの値として通す", () => {
      expect(findOptionViolations(`curl -bo jar.txt URL`)).toEqual([]);
    });

    test("消費オプション-vの値に危険文字が含まれても誤検知しない", () => {
      expect(findOptionViolations(`awk -vofs=x '{print $1}' f`)).toEqual([]);
    });

    test("-Fo,のような結合短縮形はFの値として通す", () => {
      expect(findOptionViolations(`awk -Fo, '{print $1}' file.csv`)).toEqual(
        [],
      );
    });

    test("-v OFS=の大文字Oは危険文字oと別なので通す", () => {
      expect(findOptionViolations(`awk -v OFS=' ' '{print}' f`)).toEqual([]);
    });

    test("クラスタ内でiが消費文字より先に出現すれば検出する", () => {
      expect(descriptionsOf(`sed -ie 's/a/b/' f`)).toContain("sed の -ie");
    });

    test("--以降の引数はオプション扱いしない", () => {
      expect(
        findOptionViolations(`awk '{print}' -- -file-with-dashes`),
      ).toEqual([]);
    });

    test("安全な-f実行をブロックしない", () => {
      expect(findOptionViolations(`awk -f prog.awk data.txt`)).toEqual([]);
    });

    test("安全なsed実行をブロックしない", () => {
      expect(findOptionViolations(`sed -n '1,5p' file`)).toEqual([]);
    });

    test("パイプ先が安全なawkの場合をブロックしない", () => {
      expect(
        findOptionViolations(`cat /etc/passwd | awk -F: '{print $1}'`),
      ).toEqual([]);
    });
  });
});

describe("findEmbeddedExecution", () => {
  describe("awkの実行構文の検出", () => {
    test("BEGINブロックのsystem()を検出する", () => {
      expect(
        findEmbeddedExecution(`awk 'BEGIN{system("git push")}' f`),
      ).toBe("awk の system() 呼び出し");
    });

    test("アクション内のsystem()を検出する", () => {
      expect(findEmbeddedExecution(`awk '{system($1)}' f`)).toBe(
        "awk の system() 呼び出し",
      );
    });

    test("printのパイプ先コマンドを検出する", () => {
      expect(findEmbeddedExecution(`awk '{print | "sh"}' f`)).toBe(
        "awk の print のパイプ先コマンド",
      );
    });

    test("getlineへのコマンドパイプを検出する", () => {
      expect(
        findEmbeddedExecution(`awk '{"cmd" | getline line}' f`),
      ).toBe("awk の getline へのコマンドパイプ");
    });

    test("コプロセス|&を検出する", () => {
      expect(findEmbeddedExecution(`gawk '{print $1 |& "sh"}' f`)).toBe(
        "gawk の コプロセス |&",
      );
    });

    test("パイプ後方セグメントのawkでも検出する", () => {
      expect(
        findEmbeddedExecution(`printf 'x\\n' | awk 'BEGIN{system("id")}'`),
      ).toBe("awk の system() 呼び出し");
    });
  });

  describe("sedの実行構文の検出", () => {
    test("単独のeコマンドを検出する", () => {
      expect(findEmbeddedExecution(`printf 'ls\\n' | sed -n 'e'`)).toBe(
        "sed の e コマンド",
      );
    });

    test("連結されたeコマンドを検出する", () => {
      expect(findEmbeddedExecution(`sed 's/a/b/;e' f`)).toBe(
        "sed の e コマンド",
      );
    });

    test("s///eフラグを検出する", () => {
      expect(findEmbeddedExecution(`echo ls | sed 's/.*/&/e'`)).toBe(
        "sed の s///e フラグ",
      );
    });

    test("s///geフラグを検出する", () => {
      expect(findEmbeddedExecution(`echo ls | sed 's/.*/&/ge'`)).toBe(
        "sed の s///e フラグ",
      );
    });

    test("区切り文字が#でもs///eを検出できる", () => {
      expect(findEmbeddedExecution(`echo ls | sed 's#.*#&#e'`)).toBe(
        "sed の s///e フラグ",
      );
    });
  });

  describe("誤検知しないケース", () => {
    test("正規表現リテラル内のsystem(は無視する", () => {
      expect(findEmbeddedExecution(`awk '/system\\(x/{print}' f.c`)).toBeNull();
    });

    test("rgの引数にあるsystem(は無視する", () => {
      expect(findEmbeddedExecution(`rg 'system\\(' notes.md`)).toBeNull();
    });

    test("通常の置換は無視する", () => {
      expect(findEmbeddedExecution(`sed 's/error/ERR/g' f`)).toBeNull();
    });

    test("パイプや実行構文のないコマンドは無視する", () => {
      expect(findEmbeddedExecution(`awk -F, '{print $1}' f`)).toBeNull();
    });
  });
});

describe("isRealFileWrite", () => {
  test("`>`によるファイル書き込みを検出する", () => {
    expect(isRealFileWrite(`echo hi > out.txt`)).toBe(true);
  });

  test("`>>`による追記も書き込みとみなす", () => {
    expect(isRealFileWrite(`echo hi >> out.txt`)).toBe(true);
  });

  test("/dev/nullへのリダイレクトは書き込みとみなさない", () => {
    expect(isRealFileWrite(`echo hi > /dev/null`)).toBe(false);
  });

  test("リダイレクトがないコマンドを書き込みとみなさない", () => {
    expect(isRealFileWrite(`ls -la`)).toBe(false);
  });
});

describe("findPipedExecution", () => {
  describe("パイプ実行の検出", () => {
    test("curlからbashへのパイプ実行を検出する", () => {
      expect(
        findPipedExecution(`curl https://example.com/install.sh | bash`),
      ).toBe("curl から bash へのパイプ実行");
    });

    test("スペースなしのパイプも検出できる", () => {
      expect(findPipedExecution(`curl -s https://x.example|sh`)).toBe(
        "curl から sh へのパイプ実行",
      );
    });

    test("sudo経由の実行を検出できる", () => {
      expect(findPipedExecution(`curl URL | sudo bash`)).toBe(
        "curl から bash へのパイプ実行",
      );
    });

    test("シェルのオプション付き起動を検出できる", () => {
      expect(findPipedExecution(`curl URL | bash -s -- args`)).toBe(
        "curl から bash へのパイプ実行",
      );
    });

    test("フルパスのシェルを検出できる", () => {
      expect(findPipedExecution(`curl URL | /bin/sh`)).toBe(
        "curl から sh へのパイプ実行",
      );
    });

    test("スクリプト言語へのパイプを検出できる", () => {
      expect(findPipedExecution(`curl URL | python3`)).toBe(
        "curl から python3 へのパイプ実行",
      );
    });

    test("中間コマンド越しのパイプ先を検出できる", () => {
      expect(findPipedExecution(`curl URL | jq . | bash`)).toBe(
        "jq から bash へのパイプ実行",
      );
    });

    test("xargs経由のbashを検出できる", () => {
      expect(findPipedExecution(`find . -name '*.sh' | xargs bash`)).toBe(
        "find から bash へのパイプ実行",
      );
    });

    test("サブシェル内のパイプ実行を検出できる", () => {
      expect(findPipedExecution(`(curl URL | bash)`)).toBe(
        "curl から bash へのパイプ実行",
      );
    });

    test("リダイレクト混在でもパイプ実行を検出できる", () => {
      expect(findPipedExecution(`curl URL > /dev/null | bash`)).toBe(
        "curl から bash へのパイプ実行",
      );
    });
  });

  describe("||接続は検出しない", () => {
    test("curl失敗時のfallback実行を検出しない", () => {
      expect(findPipedExecution(`curl URL || bash fallback.sh`)).toBeNull();
    });

    test("cat失敗時のsh起動を検出しない", () => {
      expect(findPipedExecution(`cat x || sh`)).toBeNull();
    });
  });

  describe("誤検知しないケース", () => {
    test("&&接続は検出しない", () => {
      expect(findPipedExecution(`curl URL && bash setup.sh`)).toBeNull();
    });

    test(";接続は検出しない", () => {
      expect(findPipedExecution(`curl URL; bash setup.sh`)).toBeNull();
    });

    test("改行接続は検出しない", () => {
      expect(findPipedExecution("curl URL\nbash setup.sh")).toBeNull();
    });

    test("引用符内の縦棒は検出しない", () => {
      expect(findPipedExecution(`echo "a | bash"`)).toBeNull();
    });

    test("引数としてのbashは検出しない", () => {
      expect(findPipedExecution(`man bash | less`)).toBeNull();
    });

    test("安全なパイプ先は検出しない", () => {
      expect(findPipedExecution(`curl URL | jq .`)).toBeNull();
    });
  });
});
