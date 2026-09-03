## Conversation Guidelines
- Always respond in Japanese
- ユーザーの意見に忖度せず、忌憚のない意見を述べる。技術的に問題がある場合や、より良いアプローチがある場合は率直に指摘する

## 開発フロー（start-work の自動利用）
- **設計と実装を含む指示**（機能追加・バグ修正・リファクタ・issue 対応など、コード変更を伴うもの）を受けたら、まだ `start-work` スキルを使っていない場合は**自動的に `start-work` スキルを起動**し、その標準フロー（ブランチ → 計画 → 設計 → テスト → 実装 → テスト実行 → E2E → PR → 自己レビュー）に従う。
- すでに `start-work` が起動済みの場合は二重起動しない。
- 例外: 単発の調査・質問・説明のみで実装を伴わない依頼、明らかに些細な変更でユーザーが直接の対応を求めている場合は、判断でスキップしてよい。

## issue 起票のルール（issue-structure の自動利用）

> スキルの正源は `eversense/es-claude-plugins` の `es-workflows` プラグイン。プラグイン経由なら `es-workflows:issue-structure`、ローカル配置なら `issue-structure` で起動する。

- **issue を起票するとき（`start-work` Phase 1 でも、それ以外の経路でも）、起票が 2 本以上になる場合は必ず `issue-structure` スキルを起動**し、親issue（必要ならトラッキングissue）と各リポジトリの作業issueを作って sub-issue と「関連」で結ぶ。単発issueを並べて作らない。プロジェクト・リポジトリ構成は問わない（単一リポジトリ構成でも同一リポジトリ内で階層を作る）。
- **2 本以上になる判定**: 変更が複数リポジトリに及ぶ（例: API + クライアント + 管理画面）／独立した作業単位が複数あり複数PRに分ける必要がある／同一の解決単位に対して別リポジトリの対応が必要。
- 起票が 1 本で済む場合は `issue-structure` を使わない（階層を作らない）。
- 起票後に「実は複数リポジトリに及ぶ」と判明した場合は、その時点で `issue-structure` の**後追い構造化**を使って上位階層を付ける。

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
- **PR は自己レビューを収束させる**: PR 作成後、マージ前に必ず自分で diff を通しレビューする。**先にラウンド上限（1/2/3）を決め**、指摘を Blocker / Should / Nit に分類し、**Blocker・Should が枯れたら完了**（Nit でループを伸ばさない）。上限到達時は残指摘を提示してユーザーの判断を仰ぐ。**フルテスト / E2E は最終ゲートで 1 回**。詳細は `~/.claude/rules/self-review-before-merge.md`
- **E2E テストは必ず実行しグリーンにする**: 変更を完了と見なす前・マージ前に、影響範囲の E2E を実行し全通過を確認する。通すためにテストを骨抜きにしない。E2E が無い/該当しない変更は最上位テスト（統合→ユニット）で代替しその旨を明示。詳細は `~/.claude/rules/e2e-must-pass.md`
- **worktree は PR 作成後に削除する**: issue ごとに作った git worktree は、PR を作成した時点で削除する（`git worktree remove` → `git worktree prune`）。各ツリーに `node_modules` / ビルド成果物が個別に生成されるため放置すると数十 GB 規模で膨らむ。未コミットのソース変更がある場合は強制削除せず確認する。ブランチは消さない。詳細は `~/.claude/rules/worktree-cleanup.md`
- **コミット衛生**: 1コミット=1論理変更（atomic）。conventional commits 形式（`feat:`/`fix:`/`chore:` 等）で、body に why を書く。無関係な変更・整形を同一コミットに混ぜない。squash 前提の雑な WIP を積まない。詳細は `~/.claude/rules/commit-hygiene.md`

