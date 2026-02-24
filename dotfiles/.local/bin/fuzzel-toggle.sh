#!/usr/bin/env bash
set -euo pipefail

if pgrep -x "fuzzel" >/dev/null; then
  pkill -x "fuzzel"
else
  # 允许失焦（别的窗口可拿到键盘焦点）→ 失焦就自动退出（默认行为）
  fuzzel --keyboard-focus=on-demand \
   --anchor=center \
  &
fi