# Global Coding Conventions

## Private Members
クラス内のプライベートメソッド・プライベートプロパティには必ず `_` を先頭につけること。

```typescript
// OK
class User {
  private _name: string;
  private _validate(): boolean { ... }
}

// NG
class User {
  private name: string;
  private validate(): boolean { ... }
}
```

## File Naming
ファイル名は `snake_case` を使用すること（例: `server_pool.ts`）。`kebab-case`（`server-pool.ts`）は使わない。

```
// OK
server_pool.ts
user_repository.ts

// NG
server-pool.ts
user-repository.ts
```

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

## 短い関数のインライン化
1箇所でしか使われない関数は、インライン化を検討する。

### 判断基準

**インライン化すべき:**
- 関数名が処理を説明する必要がない（代入や単純な操作）
- 呼び出し元で何をしているか自明

**インライン化しない方が良い:**
- 関数名が意図を明確にする（`hasChanged` は「変化したか」を明確に説明）
- 名前をつけることでコードの可読性が向上する

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

## 内部処理が1行の関数のインライン化
関数の内部処理が1行の場合、インライン化を検討する。

### インライン化すべき

- **既存メソッドのラッパーになっている**: 関数名の動詞が内部メソッドと同じ（例: `findScriptSetting` → `.find()`）
- **呼び出し元で処理が理解できる**: インライン化してもコードの意図が明確

### インライン化しない

- **関数名が独自の意味を持つ**: 例: `isEnabled()` は内部が1行でも「有効か」を明確に説明

## インポートのまとめ
同じモジュールからのインポートは1行にまとめる。

## 名前衝突の解決（import エイリアス）
プロジェクト内の型（モデルなど）と外部ライブラリの型が同名で衝突する場合、
単純名のまま放置せず、import エイリアス（またはモジュールプレフィックス）で区別する。

1. **フル修飾名をコード内に直書きしない**。長い修飾名（例 `com.google.example.Foo`）は
   インラインに書かず import で別名を付ける。
2. **衝突した2つの型それぞれに、出所がわかる別名を付ける**。
   - プロジェクト独自の型 → ドメイン名を接頭辞（例: `Payload` → `EpidemicPayload`）
   - 外部ライブラリの型 → ライブラリ/機能名を接頭辞（例: GMS Nearby → `NearbyPayload`）
3. 衝突していない型には余計なエイリアスを付けない。

```
// NG: フル修飾名を直書き
val a = com.google.example.Payload(...)
val b = com.google.android.gms.nearby.Payload(...)

// OK: 出所が分かる別名を付ける
import com.google.example.Payload as EpidemicPayload
import com.google.android.gms.nearby.Payload as NearbyPayload

val a = EpidemicPayload(...)
val b = NearbyPayload(...)
```

## 関数の書き方
JavaScript, TypeScriptの通常関数はアロー関数で書く。JSXコンポーネントは`function`のままでよい。
return文しかない関数はreturnを省略する。

```
// NG: 同じモジュールから2行でインポート
import type { ScriptSetting } from "~/models/script_setting";
import { SCRIPT_SETTINGS_KEY } from "~/models/script_setting";

// OK: 1行にまとめる
import { SCRIPT_SETTINGS_KEY, type ScriptSetting } from "~/models/script_setting";
```

## Test Naming Conventions

テスト名は**仕様ドキュメント**として読めるように書く。テストランナーの出力がそのまま仕様一覧になることを意識する。

### 文体（普通体／可能形）
- **仕様の記述** → 普通体（終止形 `〜する`）
  - `getUserNameの値を返す`
  - `不正な入力でArgumentErrorを投げる`
- **使い方・ユースケース** → 可能形（`〜できる`）
  - `switch文でパターンマッチできる`
  - `バイト列から復元できる`

### group 名
テストの主題（クラス名やメソッド名）で始める。

```
group('Payload')                    # クラス名
group('fromJson')                   # メソッド名
group('全フィールドに値が必要')      # クラス名を親groupで示せている場合
```

### コード参照と日本語の間のスペース
変数名・メソッド名・キーワードなどのコード参照の直後には**スペースを入れない**。

```
getUserNameの値を返す          # OK
getUserName の値を返す          # NG
```

### テストファイルの構造
1テストファイル＝1クラス（または1機能単位）。パッケージ構成を test/ 以下にミラーする。

### テストの構造化
テスト対象メソッドごとにテストを分ける。同一メソッドの成功・失敗テストは同じグループにまとめる。

```
# OK: メソッドごとにまとめている
GetUserName
├── 成功時にユーザー名を返す
└── engine例外時にNATIVE_GET_USERNAMEエラーを返す

# NG: 成功と失敗が別々の場所にある
OnMethodCall
├── GetUserName（成功のみ）
└── ...
OnMethodCallFailure
├── GetUserName（失敗のみ）
└── ...
```

### 失敗パスも書く
成功パスだけでなく、例外・エラーパスもテストする。各メソッドのtry/catchパスを網羅的にカバーする。
