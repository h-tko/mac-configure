#!/bin/bash
# SessionStart フック: このセッションの応答まとめの書き出し先を決めて Claude に伝え、
# cmux 上なら Claude の右にまとめ表示ペインを開く。
# - Conductor 上では既存の .context/summary.md を使う（Conductor のアクションで表示できる）
# - 同じファイルを表示中のペインがあれば開き直さない（compact 等で何度も呼ばれるため）
# - /clear でファイルが変わったら、同じ Claude の古い表示ペインを閉じて開き直す

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

if [ -n "$CONDUCTOR_WORKSPACE_PATH" ]; then
	file="$CONDUCTOR_WORKSPACE_PATH/.context/summary.md"
elif [ -n "$session_id" ]; then
	file="$HOME/.claude/session-summaries/$session_id.md"
else
	exit 0
fi
mkdir -p "$(dirname "$file")"

viewer="$HOME/.claude/scripts/session-summary-view.sh"
if [ -n "$CMUX_SURFACE_ID" ] && command -v cmux >/dev/null 2>&1 && [ -x "$viewer" ]; then
	if ! pgrep -f "session-summary-view.sh $file" >/dev/null; then
		[ -n "$CMUX_CLAUDE_PID" ] && pkill -f "session-summary-view.sh .* $CMUX_CLAUDE_PID\$"
		cmux new-split right --surface "$CMUX_SURFACE_ID" --focus false \
			--command "exec '$viewer' '$file' $CMUX_CLAUDE_PID" >/dev/null 2>&1
	fi
fi

jq -n --arg f "$file" '{
	hookSpecificOutput: {
		hookEventName: "SessionStart",
		additionalContext: ("このセッションの応答まとめファイル: " + $f + "（CLAUDE.md「応答まとめ」に従い、毎ターン末尾でこのファイルを上書きする）")
	}
}'
