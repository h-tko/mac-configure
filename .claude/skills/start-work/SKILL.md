---
name: start-work
description: 標準開発フローを毎回同じ順序で固定実行するコマンド。ユーザーが「/start-work」と入力した時、またはコード変更タスク（issue 対応・機能追加・バグ修正）の開始時に使用。ブランチ → 計画 → 設計 → テスト → 実装 → テスト実行 → E2E → PR → 自己レビュー → 退避(アーカイブ) の順に進める。進行中の作業記憶は `.es-flow/` に貯め、最後に es-work-log へ 1 回だけ退避する。各フェーズはグローバル rules（tdd / verification-before-completion / e2e-must-pass / self-review-before-merge / no-test-code-in-production）とプロジェクトの CLAUDE.md に従う。
---

# /start-work — 標準開発フロー（固定）

コード変更タスクは**毎回このフェーズ順で**進める。起動したら、まず下記「全体チェックリスト」を TodoWrite に展開し、各フェーズを順に in_progress → completed にしながら進める。**承認ゲート（Phase 1・2）を飛ばして先のフェーズに進まない。**

> **プロジェクト規約が最優先**。base ブランチ名・commit 粒度・RED 後の停止有無・設計ドキュメントの置き場・受け入れ条件の在処・各種コマンドは、対象リポジトリの `CLAUDE.md` / `justfile` に従う。本コマンドはどのプロジェクトでも変わらない「順序と関門」を固定する。

---

## 作業記憶（`.es-flow/` スクラッチパッド）と退避

進行中の作業記憶は作業ツリー直下の `.es-flow/`（scratchpad、**git 管理外**＝プロジェクトの `.gitignore` に追加し、フィーチャーブランチにコミットしない）に置く。

- `.es-flow/notes.md` — 調査メモ
- `.es-flow/review-log.md` — 自己レビュー各ラウンドの詳細ログ
- `.es-flow/plan.md` — （必要時のみ）issue 起票に失敗した場合の計画フォールバック
- `.es-flow/logs/` — テスト・lint・typecheck・build の出力
- `.es-flow/e2e/` — E2E 実行ログ・スクリーンショット
- `.es-flow/README.md` — 作業概要（退避先では `es-flow/README.md` になる）

**ルール:**

1. **Phase 10 までは `.es-flow/` を一切アップロード（退避）しない**。テストログ・E2E ログ・スクショ・`README.md` を含め、すべて `.es-flow/` 直下にローカルで貯める。後から見返したい出力（テスト結果・スクショ等）はここに残す（Phase 10 でまるごと退避される）。
2. **issue コメントに残すもの**: **レビューの最終結果サマリ・E2E の結果**は、Phase 1 で作成した **issue のコメント**に残す（各ラウンドの詳細は `.es-flow/` 内の log のみで可）。
3. **退避は Phase 10 で 1 回だけ**行う（途中で小出しにアップロードしない）。退避先・命名は Phase 10 を参照。

---

## Phase 1 — ブランチ 🚦（承認ゲート）

1. **Issue 確認**: 対応する Issue が指定されているか確認する。**指定されていなければ、まず「Issue を作成するか」をユーザーに確認する**（プロジェクト規約が Issue 起票を求める場合は特に必須）。作成する場合はタイトル・本文（背景 / 受け入れ条件）を提案し、承認を得てから起票する。ユーザーが「不要」と明示した場合のみ Issue なしで進む
2. **要件理解**: 対応する Issue / 要件を読む。受け入れ条件・影響範囲を把握。不明点・複数解釈は**推測せず質問する**
3. **ベースブランチの最新化**: ブランチを切る前に、現在のブランチがリポジトリのベース（メイン）ブランチかを確認する。ここで言うメインブランチは `main` 固定ではなく、**リポジトリでメインブランチとして設定されているブランチ**（プロジェクト規約で定めたベースブランチ。例: `develop_v0.0.1`）を指す。**メインブランチでない場合は、そのブランチに切り替え → 最新を pull → そこから新ブランチを切る**。すでにメインブランチ上にいる場合も、ブランチを切る前に最新を pull する
4. **ブランチ提案**: `<type>/<issue#>-<slug>`（例: `feature/223-past-workplaces` / `fix/118-login-redirect`）を提案し、**ユーザーの許可を得てから**ブランチを切る（勝手に作らない）。**ブランチ名に issue 番号を含める**ことで Phase 10 の archive が退避先を自動でキーできる（含められない場合は Phase 10 で `--issue NNN` を明示）。base ブランチはプロジェクト規約に従う

## Phase 2 — 計画 🚦（承認ゲート）

- 変更対象ファイル・影響範囲・テスト方針を提示し、**ユーザーの承認を得てから**先へ進む
- ここまでの2つの承認（ブランチ / 計画）が揃うまで、設計・実装に入らない

## Phase 3 — 設計

- 必要に応じて、該当パッケージの設計ドキュメント（`docs/` 等）を先に更新する（手順の原則: **仕様 → 設計 → コード**）
- データフロー・インターフェース・データモデルへの影響を明示する
- 大きめの変更はここで設計レビューを挟んでよい（`/plan-eng-review`・`/plan-design-review`）

## Phase 4 — テスト（先に書く）

`~/.claude/skills/tdd`（t-wada 方式）に従う。

1. 受け入れ条件・エッジケースから**テストリストを導出**
2. **Red**: 最小のテストを1つ書き、**失敗を確認**する
3. テストと実装の commit 分離・RED 後の停止有無はプロジェクト規約に従う

## Phase 5 — 実装

1. **Green**: 仮実装で最速で通す
2. **Refactor**: 通したまま整理する
3. **本番コードにテスト用分岐を入れない**（`~/.claude/rules/no-test-code-in-production.md`）

## Phase 6 — テスト実行（証拠ベース）✅

`~/.claude/rules/verification-before-completion.md` に従い、**主張の前に実行して出力で裏取り**する。

- ユニット / 統合テストを実行しグリーンを確認
- lint / typecheck / build を実行
- 結果（pass 件数等）を後の報告 / PR に**証拠として残す**
- テスト・lint・typecheck・build の出力は `.es-flow/logs/` に保存する（Phase 10 で退避）

## Phase 7 — E2E ✅

`~/.claude/rules/e2e-must-pass.md` に従う。

- 影響範囲の **E2E を実行しグリーン（全通過）**を確認
- 通すためにテストを骨抜きにしない
- E2E が無い / 該当しない場合は最上位テスト（統合 → ユニット）で代替し、**その旨を明示**
- **結果をスクリーンショットとして取得する**: E2E（または代替で行ったブラウザ / 手動検証）の結果を**スクリーンショットで残す**。対象は「全通過のテストランナー出力」や「変更が反映された主要画面・操作後の状態（before/after があれば両方）」。**`.es-flow/e2e/` に保存**し（E2E 実行ログも同様）、**Phase 8 で PR に添付する**（添付方法は Phase 8 を参照）
- 縮退（E2E 無し）の場合も、ブラウザ / 手動で確認した画面のスクリーンショットを `.es-flow/e2e/` に保存し、**何を確認したか**を添えて PR に添付する
- **E2E の結果（pass 件数・確認内容のサマリ）を Phase 1 の issue のコメントに残す**（詳細ログ・スクショは `.es-flow/e2e/` のみで可）

## Phase 8 — PR

1. **PR を作成**する（テストが書けた段階で Draft でもよい）。プロジェクト規約に Issue 紐付け（`Closes #NN`）があれば従う
2. PR 本文に **Summary / 変更内容 / Test plan**（Phase 6・7 の結果）を記載
3. **Phase 7 のスクリーンショット / 動画を PR に添付する**（必須）。Test plan セクション等に埋め込む。画像には**何を示すか**のキャプション（例: 「E2E 全通過」「<機能> 操作後の画面」）を必ず添える。

   **添付方法は GitHub Releases のアセットを使う**（リポジトリを肥大化させず、動画も自動プレーヤー化できるため）。手順:

   1. **アセットをアップロード**（専用の prerelease タグに置く。`gh` の `--repo OWNER/REPO` で対象リポジトリを明示）
      ```bash
      # 初回（タグ pr-assets を作成してアップロード）
      gh release create pr-assets demo.mp4 screenshot.png --repo OWNER/REPO --prerelease --notes "PR assets"
      # 既存タグに追加
      gh release upload pr-assets newfile.png --repo OWNER/REPO
      ```
   2. **URL を取得**（固定形式）: `https://github.com/OWNER/REPO/releases/download/pr-assets/FILENAME`
   3. **PR 本文に埋め込む**:
      ```markdown
      ![スクショ](https://github.com/OWNER/REPO/releases/download/pr-assets/screenshot.png)

      https://github.com/OWNER/REPO/releases/download/pr-assets/demo.mp4   ← 動画は素の URL で自動プレーヤー化
      ```
   4. **PR に反映**: 新規は `gh pr create --body-file pr-body.md`、既存は `gh pr edit NN --body-file pr-body.md`

   注意点:
   - **公開範囲はリポジトリに一致**（public リポジトリだとアセットも誰でもアクセス可）。**機密ファイルは置かない**
   - **ファイル名はスペース・特殊文字を避ける**（URL エンコードが必要になり面倒）
   - **PR が参照中のアセットは消さない**（リリースを消すとリンク切れ）。専用タグ `pr-assets` のまま残す
   - `--prerelease` を付ける（通常のリリース一覧に混ざらない）。上限は 1 ファイル 2GB
   - これが使えない場合のみ、スクショのファイルパスと内容説明を本文に明記し PR コメントで添付する（フォールバック）

## Phase 9 — 自己レビュー 🔁（指摘ゼロまで）

`~/.claude/rules/self-review-before-merge.md` に従う。

1. 自分の diff を**通しでレビュー**（観点: 仕様整合 / バグ / テストカバレッジ / セキュリティ / 不要変更の混入）
2. レビュー手段は `/review`・`/code-review`・`/codex` を活用してよい
3. 指摘を修正し検証（Phase 6・7 に戻る）→ 再レビュー。**新たな指摘が出なくなるまで反復**
4. 各ラウンドの詳細は `.es-flow/review-log.md` に記録し、**最終結果サマリを Phase 1 の issue のコメントに残す**

## Phase 10 — 退避（es-work-log へアーカイブ）📦

`.es-flow/` の中身を **1 回だけ** es-work-log の **`<org>/<repo>/issue-NNN/es-flow/`** にまるごと退避する（`.es-flow/README.md` → `es-flow/README.md`）。

- 退避先フォルダは **issue 番号でキーする**（ブランチ名ではない）
- issue 番号は archive スクリプトがブランチ名 `<type>/<issue#>-<slug>` から自動抽出するか、`--issue NNN` で明示する
- **issue が存在しない（Phase 1 で起票しなかった / 起票に失敗した）場合は退避先を issue でキーできない**。その場合は**理由を付けて報告し、退避をスキップする**（silent skip 禁止）

---

## 禁止

- Phase 1・2 の承認を得ずに設計 / 実装を始める
- Red を確認せずに実装する / テストリスト無しで始める
- 実行・検証せずに「完了」「動く」と報告する
- E2E / テストを骨抜きにして緑に見せる
- 自己レビューをせずにマージ / レビュー依頼へ進む
- 依頼にトレースできない無関係な変更を混ぜる（外科的変更）
- `.es-flow/` を Phase 10 より前に退避（アップロード）する / 小出しにアップロードする
- `.es-flow/` をプロジェクトのフィーチャーブランチにコミットする（git 管理外に保つ）
- 退避を理由を告げずにスキップする（silent skip）

## 全体チェックリスト（起動時に TodoWrite へ展開）

- [ ] Phase 1: Issue 確認（無ければ作成可否を確認）→ 要件理解・不明点質問 → ベースブランチへ切替＆最新化 → ブランチ承認（`<type>/<issue#>-<slug>`）
- [ ] Phase 2: 実装計画の承認
- [ ] Phase 3: 設計（docs 更新・影響範囲明示）
- [ ] Phase 4: テストリスト → Red（失敗確認）
- [ ] Phase 5: 実装（Green → Refactor）
- [ ] Phase 6: ユニット/統合・lint/typecheck/build グリーン（証拠）→ 出力を `.es-flow/logs/` へ
- [ ] Phase 7: E2E グリーン（or 縮退を明示）→ スクショ/ログを `.es-flow/e2e/` へ → 結果サマリを issue コメントへ
- [ ] Phase 8: PR 作成 + 本文（Summary/変更/Test plan）+ Phase 7 のスクリーンショットを添付
- [ ] Phase 9: 自己レビュー → 指摘ゼロまでループ（詳細を `.es-flow/review-log.md`、最終サマリを issue コメントへ）
- [ ] Phase 10: `.es-flow/` を es-work-log（`<org>/<repo>/issue-NNN/es-flow/`）へ 1 回だけ退避（issue 無しなら理由付きでスキップ報告）
