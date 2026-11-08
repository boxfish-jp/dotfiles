---
name: code-design
description: コードを書く・設計する・既存コードを見直すときに必ずロードする。構造の分割・統合・抽出・インライン化、共有・距離・命名、過剰な間接参照、結合が強すぎる箇所、非対称な既存コード、custom hook と購読の設計判断を扱う。状態の持ち方・防御やガードの削除は state-design、実装後のレビューは review に任せる。
metadata:
  owner: boxfish
  type: Encoded Preference
  assumptions: コードの構造・分割・共有・命名の設計判断を対象にする
  retirement: この設計判断のワークフローが変わったとき
---

# Code Design

## When to apply

使う:

- コードの分割・統合・抽出・インライン化を決める
- 共有するか、距離を取るかを決める
- 命名や過剰な間接参照を見直す

使わない:

- 状態の持ち方・防御やガードの削除（`state-design`）
- 実装後のレビュー（`review` / `state-reduction-review`）

## Hookとロジックの結合
custom hookに関連するロジック関数が1箇所でしか使われない場合、ファイルを分割せずhook内にまとめる。ロジック関数とhookが密接に関わる場合は同一ファイルに置く。

```
// OK: hookとロジックが同一ファイル
use_script_settings.ts
├── useScriptSettings()        # hook
├── getScriptSettings()        # ロジック
└── updateScriptSetting()      # ロジック

// NG: 1箇所しか使わないロジックを別ファイルに分割
script_settings.ts             # ロジックのみ
use_script_settings.ts         # hookのみ
```

## データ加工の重複排除
異なる2箇所で同じデータ加工を行う場合、その処理を関数として切り出して共通化する。

```
// NG: 同じ加工を2箇所で書いている
const updateEnabled = (name: string, enabled: boolean) => {
  await updateScriptSetting(name, { enabled });
  setSettings((prev) => prev.map((s) => s.name === name ? { ...s, enabled } : s));
};

// OK: 加工関数を切り出す
function mergeScriptSetting(settings, name, updates) {
  return settings.map((s) => s.name === name ? { ...s, ...updates } : s);
}

const updateEnabled = (name: string, enabled: boolean) => {
  await updateScriptSetting(name, { enabled });
  setSettings((prev) => mergeScriptSetting(prev, name, { enabled }));
};
```

## 共有は証拠で決める（構造予測ではない）

「現在実際に一致している」部分だけを共有する。抽出の機会は第2の実消費者が現れた瞬間であり、事前に準備するものではない。

- 将来の拡張余地（payloadの入り口など）のためにstate構造や共有境界を設計しない。型も同順: 素の string union で足りるなら object union にしない。必要になった側だけ拡張する
- 単一消費者の「汎用機構」は一般化対象ではなく削除候補。登録制pub/subが消費者1組しか持たないなら、直接購読に置き換える方が簡潔なことが多い
- 過剰共有の兆候:
  - 共有stateのうち一部消費者が一切読まないフィールド（デッドフィールド）
  - 消費者の差異を吸収するためにオプショナル化された型
  - 「ラップしているから少ない」ように見えるだけの上辺の分割

```
// NG: 片側しか使わない time を全消費者の共有stateに引きずり込み、
//     durationをoptionalで吸収している
type CardState = { phase: Phase; time: number }
type Action = { type: "show"; duration?: number }

// OK: 実際に一致しているマシンだけを共有。timeは所有者のローカルstate
type Action = "show" | "hide" | "entered" | "exited"
```

## 距離の実験

距離・共有・表現は別々に決める。ここでは距離を扱い、共有の判断は「共有は証拠で決める」、表現は `state-design` と `state-reduction-review` に委ねる。

2つの要素を別のファイルやモジュールに置いたとき、離した後も同じ値・同じ順序・同じ時点でなければならないものは何か。遠い場所で値・順序・時点の一致が必要なら、結合が強すぎる。

- 名前や型の対応だけなら、同じモジュールに置く理由にはならない（型は共有したまま離してよい）
- 値の解釈が同じでなければならないなら、距離を縮めるか、共有の候補として「共有は証拠で決める」に渡す
- 呼び出し順・タイミング・同じインスタンスの共有が必要なら、距離を取るか取らないかを決める。取らないなら1メソッド・状態機械に畳み、取るなら契約として明示する（イベント契約、関数の戻り値、型）。依存方向や変更頻度を分ける証拠がある境界は、契約を明示して残してよい
- 離れた場所に値・順序・時点の一致が残り、契約にもできないなら、境界の位置をやり直す。それでも残るなら統合を検討する

例: 同じ順序で同じキャッシュを更新するなら、離さず1メソッドに畳む。

## 過剰な間接参照をしない
処理を追う関数jumpが2回以上必要な流れは、リターンなしの間接化を使っている状態。
間接化(関数分割・ラッパー・購読機構)は次のいずれかを担う時だけ正当:

- 再利用: 2人以上の実消費者がある
- 意図の命名: 関数体が読み、名前がそれを説明する
- 境界の遮断: 依存方向や変更頻度を分ける証拠がある

どれでもない素通し(Middle Man)は処理の迂回路であり、インライン化・統合の候補。
「分割してある方が整理されている」はリターンではない。

## 似たメソッドの統合
処理内容がほぼ同じメソッドが複数ある場合、引数で分岐を吸収し1つのメソッドに統合する。

```
// NG: 処理が同じメソッドが2つある
const updateEnabled = (name: string, enabled: boolean) => {
  setSettings((prev) => mergeScriptSetting(prev, name, { enabled }));
};
const updateDefaultOff = (name: string, defaultOff: boolean) => {
  setSettings((prev) => mergeScriptSetting(prev, name, { defaultOff }));
};

// OK: 1つのメソッドに統合
const updateScriptSetting = (name: string, enabled: boolean, defaultOff: boolean) => {
  setSettings((prev) => mergeScriptSetting(prev, name, { enabled, defaultOff }));
};
```

## 非対称は「そのものである必然」の主張であること

既存コードの差異（同種コンポーネント間のnull許容、ガードの有無、分岐、命名の粒度差）は、理由が確認できるまで「わざとそうである」主張とみなす。非対称であることは、非対称でなくてはならないことを意味する。

- 差異を知らずに対称化・統一するのはリファクタリングではなく設計変更
- 対称な兄弟から1つだけ外す場合も同じ。その差の理由を言えること。言えないなら残す
- 触る前に、その箇所のトリガ/挙動差異の対応を意識に置く（網羅的な表の事前作成は不要。ただし「なぜ片方だけ違うのか」を一言で説明できるかを統一の前提とする）
- 理由が特定できないなら勝手に消さず確認する。歴史残骸（挙動差なし）と確認できた場合のみ統一し、意図と判明した場合は維持した上で、理由を `coding-style` の1行 justification の範囲でコメントに残す
- 再構成の結果として挙動差（事象XでAは反応、Bは非反応等）が生む案は、明示的に採否を確定してから採用する

対の原則: 自分が新規に書く側も同じ。「対称に見えるから揃えた」は理由にならない。

## 関数のインライン化

1箇所でしか使われない関数、または内部処理が1行の関数は、インライン化を検討する。

### インライン化すべき

- 関数名が処理を説明していない（代入や単純な操作）
- 既存メソッドのラッパーになっている（例: `findScriptSetting` → `.find()`）
- 呼び出し元で何をしているか自明

### インライン化しない

- 関数名が意図を明確にする（`hasChanged` は「変化したか」を説明する）
- `isEnabled()` のように、内部が1行でも「有効か」を説明する名前を持つ
- 名前を付けることでコードの可読性が向上する

```
// インライン化すべき: 関数名は処理を説明していない
function updateLastValues(info) {
  lastTitle = info.title;
  lastEpisode = info.episode;
  lastProgress = info.progress;
}

// インライン化しない: 関数名が意図を明確に説明
function hasChanged(info): boolean {
  return (
    info.title !== lastTitle ||
    info.episode !== lastEpisode ||
    Math.abs(info.progress - lastProgress) > 1
  );
}
```

## 配置テスト（重複排除より先にやる）

データの加工・判定関数の住みかは「消費者を全部削除してもその関数は意味を持つか」で決める。

- YES → ドメイン知識。入力型を解釈するモジュール側
- NO → 消費者のpolicy。呼び出し側
- 同一式でも用途が違う場合（差分キー vs エッジ検出等）、まず「意味は同一概念か（同値関係などの1コンセプトか）」を確かめてから共有判断する。概念が同一なら用途が違っても共有してよい
- データモデルのスキーマ共有パッケージへの昇格は、別アプリ消費者が現れた時でよい

## 名前は実態を指すこと

実体と一致しない名前（曖昧な合成名、発祥側の比喩が他ドメインへ漏れた名前）は設計の臭み。

- 単一オーナーのフックはオーナー名でよい。機構名は共有の証拠が出てからの二段階を踏む
- 分割・抽出を行った後、名残った名前・定数の発祥を再監査する。ズレの改名はリファクタリングの一部であり、おまけではない

## 実装ピット（購読・custom hook・共有パッケージ）

- custom hook が dispatch/setState 関数を透過返却すると、exhaustive-deps 系lintはその安定性を追跡できなくなる。deps配列に明示列出する（実体は不変なので再実行は増えない）
- 購読を singleton emitter に統合・新設する時、解除機構の有無を先に実装まで確認する。「現時点で顕在化しないリーク」は正常ではない。無ければ付加する側が正しい
- 共有パッケージのAPI変更（戻り値追加等の後方互換に見える変更含む）は、全消費者のgrep + 各依存先パッケージのビルド通過で互換を確認する
- 解除機構の実装はテストで押さえる: 解除後の非発火、多重解除、発火中の解除で他リスナーに残りが届くこと

## 出力

- 変更案またはレビュー所見。分割・統合・抽出・インライン化・共有・距離・命名の判断を1項目ずつ書く
- 各判断に、実消費者・距離・差分の証拠を添える
- コードを書き換えた場合は、その差分

## 完了条件

- 各判断に根拠（実消費者、距離、既存の表現）を添えた
- 状態・防御・表現の判断を `state-design` に渡した
- コードを変更した場合、テストと型チェックが通る。実行できない場合は「未検証」と書いた
