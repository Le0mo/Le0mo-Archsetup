#!/usr/bin/env bash
set -euo pipefail

# 你可以把脚本放到 ~/.config/waybar/scripts/island/
BASE="$HOME/.config/waybar/scripts/island"

pkill -f "$BASE/island.py" 2>/dev/null || true
pkill -f "$BASE/lyrics_island.py" 2>/dev/null || true

nohup python3 "$BASE/island.py" >/tmp/island.log 2>&1 &
nohup python3 "$BASE/lyrics_island.py" >/tmp/lyrics_island.log 2>&1 &
