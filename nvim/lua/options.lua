do
  -- デフォルトで行番号を表示する
  vim.o.number = true
  -- ジャンプの補助として、相対行番号を追加することもできます。
  vim.opt.relativenumber = true

  -- マウスモードを有効化（例えば、ウィンドウ分割のリサイズなどに役立ちます！）
  vim.o.mouse = 'a'

  -- 行折り返し時のインデントを有効化
  -- vim.o.breakindent = false

  -- ファイルを閉じて再度開いた後でも、変更の取り消し/やり直し（undo/redo）を有効にする
  vim.o.undofile = true

  -- 検索語に \C または1つ以上の大文字が含まれていない限り、大文字小文字を区別せずに検索する
  vim.o.ignorecase = true
  vim.o.smartcase = true

  -- デフォルトでサインカラム（行番号の横の記号表示欄）を表示したままにする
  vim.o.signcolumn = 'yes'

  -- 更新時間を短縮する（入力待機などの反応を良くする）
  vim.o.updatetime = 250

  -- マップされたキーシーケンスの待機時間を短縮する
  vim.o.timeoutlen = 300

  -- 新しい分割ウィンドウの開き方を設定する（右側と下側に開く）
  vim.o.splitright = true
  vim.o.splitbelow = true

  -- エディタ内で特定の空白文字をどのように表示するかを設定します。
  -- 詳細は `:help 'list'`
  -- および `:help 'listchars'` を参照
  --
  -- listchars は `vim.o` ではなく `vim.opt` を使用して設定されていることに注意してください。
  -- これは `vim.o` と非常に似ていますが、テーブルを便利に操作するためのインターフェースを提供します。
  -- 詳細は `:help lua-options`
  -- および `:help lua-guide-options` を参照
  vim.o.list = true
  vim.opt.listchars = { tab = '» ' }

  -- 入力中に置換結果をリアルタイムでプレビューする！
  vim.o.inccommand = 'split'

  -- カーソルが現在どの行にあるかを表示する（カーソル行をハイライト）
  vim.o.cursorline = true

  -- バッファに保存されていない変更があるために失敗する操作（`:q` など）を実行しようとした場合、
  -- 代わりに現在のファイル（群）を保存するかどうかを尋ねるダイアログを表示します
  -- 詳細は `:help 'confirm'` を参照
  vim.o.confirm = true
end
