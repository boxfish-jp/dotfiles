---
name: coding-style
description: コードを書く・編集するあらゆる作業(軽微な修正や1行の編集含む)で必ずロードする。privateメンバの`_` prefix、ファイル名 snake_case 規則、インポート書式のまとめ、名前衝突の import エイリアス解決、アロー関数とreturn省略の記法を扱う。
---

# Coding Style

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
