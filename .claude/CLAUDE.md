## Conversation Guidelines
- Always respond in Japanese
- ユーザーの意見に忖度せず、忌憚のない意見を述べる。技術的に問題がある場合や、より良いアプローチがある場合は率直に指摘する

## Zellij ペイン管理ルール

サブエージェント（Taskツールで起動するエージェント）を使用する際、Zellijペインで視覚的に分離する。
**チームエージェント（TeamCreate + Task with team_name）も同様にペインで管理する。**

### 基本原則
- **自分が開いたペインだけを閉じる** — 既存のペイン,及び自身は絶対に閉じない。ペイン作成時にペインIDを記録し、終了時はそのIDのみを対象にする
- サブエージェント/チームメンバー1人につき1つのペインを割り当てる
- サブエージェントが完了したら、そのペインを閉じる

### ペインレイアウト
- エージェント用ペインは **Claude Codeペインを右分割** して、Claude Codeとpane#4の間に配置する
- pane#4（空ターミナル）の幅は変更しない
- 複数エージェントがいる場合、エージェント列を **エージェント数ぶん縦に等分割** する
- メインペインの下には配置しない

### 操作手順

**禁止事項**:
- `write-chars` はフォーカス依存で不安定なため使用禁止
- `move-focus` + `close-pane` でペインを閉じるのは誤ったペインを閉じるリスクがあるため禁止

#### 出力ファイルの取得

**サブエージェント**（Task単体 + `run_in_background: true`）:
- Task toolの応答に含まれる `output_file` パスをそのまま使用する

**チームエージェント**（TeamCreate + Task with `team_name` + `run_in_background: true`）:
- Task toolの応答に `output_file` が含まれないため、以下の手順で特定する:
  1. サブエージェントディレクトリのスナップショットを取得:
     ```
     ls -1 ~/.claude/projects/{project_path}/{session_id}/subagents/ | sort > /tmp/before_{agent_name}.txt
     ```
  2. エージェントを起動（**1人ずつ順番に**）
  3. 1秒待ってから新規ファイルを検出:
     ```
     sleep 1 && ls -1 ~/.claude/projects/{project_path}/{session_id}/subagents/ | sort | comm -13 /tmp/before_{agent_name}.txt -
     ```
  4. 検出されたjsonlファイルのフルパスを `output_file` として使用する
- `{project_path}` はcwdの `/` を `-` に置換し先頭に `-` を付けたもの（例: `-Users-takeo-hiroaki-Projects-foo`）
- `{session_id}` はチームconfig（`~/.claude/teams/{team_name}/config.json`）の `leadSessionId` から取得する

#### ペイン作成
フォーカスがClaude Codeペイン（caffeinate）にある状態で、全コマンドを `&&` で連結して一括実行する:
```
zellij action new-pane --direction right --name "{agent_1}" --close-on-exit -- tail -f {output_file_1} && \
zellij action new-pane --direction down --name "{agent_2}" --close-on-exit -- tail -f {output_file_2} && \
zellij action new-pane --direction down --name "{agent_3}" --close-on-exit -- tail -f {output_file_3}
```
- 1人目: `--direction right` でClaude Codeペインを右分割（フォーカスが新ペインに移動）
- 2人目以降: `--direction down` で縦分割（フォーカスは常に最新ペインに移動するため、そのまま連結可能）

#### ペインクローズ
エージェント完了時は `pkill` で `tail` プロセスを終了する。`--close-on-exit` により、プロセス終了後にペインが自動的に閉じる。
```
pkill -f "tail -f {output_file}"
```
**`move-focus` + `close-pane` は使わない**（フォーカスが意図しないペインに移動し、既存ペインを誤って閉じるリスクがあるため）。

### 注意事項
- ペイン操作前に `zellij action dump-layout` でレイアウトを確認し、既存ペイン構成を把握する
- `zellij action` のサブコマンド引数は位置引数で指定（例: `move-focus right`、`resize increase left`）。`--direction` フラグではない
- エラーでペインが残った場合のみ、`pkill` または手動でクリーンアップする
- メインペイン（Claude Codeが動作しているペイン）は絶対に閉じない

## gstack

- Web ブラウジングには必ず `/browse` スキル（gstack）を使用する。`mcp__claude-in-chrome__*` ツールは使用しない
- 利用可能なスキル: `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/plan-design-review`, `/design-consultation`, `/review`, `/ship`, `/land-and-deploy`, `/canary`, `/benchmark`, `/browse`, `/qa`, `/qa-only`, `/design-review`, `/setup-browser-cookies`, `/setup-deploy`, `/retro`, `/investigate`, `/document-release`, `/codex`, `/cso`, `/autoplan`, `/careful`, `/freeze`, `/guard`, `/unfreeze`, `/gstack-upgrade`

## 🚫 Security Rules

### NEVER Rules
- **NEVER: Delete production data**
- **NEVER: Hardcode API keys, passwords, or secrets**

## コーディングガイドライン

LLM のコーディングミスを減らすための行動指針。
原典: https://github.com/multica-ai/andrej-karpathy-skills/blob/2c606141936f1eeef17fa3043a72095b4765b9c2/CLAUDE.md
プロジェクト固有の指示と必要に応じて統合する。

**トレードオフ**: これらは速度よりも慎重さを優先する。些細なタスクでは判断で省略可。

### 1. コーディング前に考える

**仮定で進めない。混乱を隠さない。トレードオフを明示する。**

実装前に:
- 仮定を明示的に述べる。不確実なら質問する
- 複数の解釈が可能なら、それらを提示する — 黙って一つを選ばない
- より簡素なアプローチがあるなら、それを言う。妥当な場合は押し返す
- 不明点があれば止まる。何が不明か名指しして質問する

### 2. シンプルさ最優先

**問題を解決する最小限のコード。推測的な要素は入れない。**

- 要求されていない機能は加えない
- 単発使用のコードに抽象化を入れない
- 要求されていない「柔軟性」「設定可能性」を入れない
- 起こりえないシナリオへのエラーハンドリングを入れない
- 200 行書いて 50 行で済むと気づいたら、書き直す

自問: 「シニアエンジニアならこれを過剰設計と言うか?」 答えが yes なら、簡素化する。

### 3. 外科的変更

**触る必要があるものだけ触る。自分が出した残骸だけ片付ける。**

既存コードを編集する際:
- 隣接するコード / コメント / フォーマットを「改善」しない
- 壊れていないものをリファクタしない
- 自分なら別の書き方をするとしても、既存のスタイルに合わせる
- 関係のない dead code に気づいたら、削除せず指摘する

自分の変更で孤立物が生じた場合:
- **自分の変更**で未使用になった import / 変数 / 関数は削除する
- 既存の dead code は依頼されない限り削除しない

テスト: 変更したすべての行が、ユーザーの依頼に直接トレースできるか。

### 4. ゴール駆動の実行

**成功基準を定義する。検証完了までループする。**

タスクを検証可能なゴールに変換する:
- 「バリデーションを追加」→「不正入力のテストを書き、通す」
- 「バグを直す」→「再現するテストを書き、通す」
- 「X をリファクタ」→「リファクタ前後でテストが通ることを保証する」

多段タスクでは簡潔な計画を述べる:

```
1. [ステップ] → 検証: [チェック]
2. [ステップ] → 検証: [チェック]
3. [ステップ] → 検証: [チェック]
```

強い成功基準なら独立してループできる。弱い基準（「動くようにする」）は常に確認が必要になる。

---

**これらのガイドラインが機能している指標**: diff に不要な変更が減る、過剰な複雑化による書き直しが減る、ミスの後ではなく実装前に確認質問が来る。

## 横断ルール（rules/）

全プロジェクト共通の詳細ルールは `~/.claude/rules/` に分割し、ここではサマリのみ維持する。

- **本番コードへのテスト用コード混入禁止**: テスト都合で本番コードの構造を歪めない。環境分岐（mock vs 実装）を本番経路に埋め込まず、依存を interface 抽象化して DI で差し替える。同一機能の二重実装を避ける。詳細は `~/.claude/rules/no-test-code-in-production.md`（言語固有の具体例は各リポジトリの `.claude/rules/` を参照）
- **完了報告は証拠ベースで**: 「完了/直した/テストが通る/動く」と主張する前に、検証コマンドを実行し出力を確認する。推測で成功を主張せず、未検証なら「未検証」と明示する。詳細は `~/.claude/rules/verification-before-completion.md`
- **PR は自己レビューで指摘ゼロまで**: PR を作成したらマージ前に必ず自分で diff を通しレビューし、指摘ゼロになるまで「レビュー→修正→再レビュー」を反復する。レビュー手段は `/review`・`/code-review`・`/codex` 等を活用してよい。詳細は `~/.claude/rules/self-review-before-merge.md`

