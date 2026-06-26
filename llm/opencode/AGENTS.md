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
