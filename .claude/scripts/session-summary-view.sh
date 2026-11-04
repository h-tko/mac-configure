#!/bin/bash
# 応答まとめファイルを、更新されるたびに表示し直す。
# 使い方: session-summary-view.sh <まとめファイル> [監視する Claude の PID]
# PID を渡した場合、その Claude が終了したら自分も終了する（cmux の exec 起動ならペインも閉じる）。

file=$1
owner=$2
last=""
while true; do
	if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
		exit 0
	fi
	mtime=$(stat -f %m "$file" 2>/dev/null || echo none)
	if [ "$mtime" != "$last" ]; then
		last=$mtime
		if [ -t 1 ]; then
			clear
		else
			printf '\n==============================\n'
		fi
		if [ -f "$file" ]; then
			printf '更新: %s\n' "$(date -r "$mtime" '+%H:%M:%S')"
			if [ -t 1 ] && command -v glow >/dev/null; then
				glow "$file"
			else
				cat "$file"
			fi
		else
			echo "まだまとめがありません（次の応答が終わると表示されます）"
		fi
	fi
	sleep 2
done
