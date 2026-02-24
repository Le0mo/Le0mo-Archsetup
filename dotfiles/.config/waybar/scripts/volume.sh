#!/usr/bin/env bash
set -euo pipefail

TITLE="Volume"
WIDTH=30
HEIGHT=120
THEME_NAME="yad-waybar-import"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"

need() { command -v "$1" >/dev/null 2>&1 || { echo "$1 not found"; exit 1; }; }
need yad; need pactl; need awk; need pgrep; need pkill; need mktemp; need cp

# 当前音量（0-100）
CUR_VOL="$(pactl get-sink-volume @DEFAULT_SINK@ \
  | awk 'NR==1{for(i=1;i<=NF;i++) if($i ~ /%$/){gsub(/%/,"",$i); print $i; exit}}')"
CUR_VOL="${CUR_VOL:-50}"
[[ "$CUR_VOL" =~ ^[0-9]+$ ]] || CUR_VOL=30
(( CUR_VOL > 100 )) && CUR_VOL=100

# 防止重复弹窗
pkill -f "yad --scale.*--title=${TITLE}" 2>/dev/null || true

# 临时 GTK3 主题（导入 waybar colors.css）
TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT
GTKDIR="$TMPDIR/share/themes/$THEME_NAME/gtk-3.0"; mkdir -p "$GTKDIR"
cp "$WAYBAR_DIR/colors.css" "$GTKDIR/colors.css"

cat > "$GTKDIR/gtk.css" <<'CSS'
@import "colors.css";

window { background-color: @surface_container_high; border-radius: 5px; padding: 12px; }
scale { padding: 0; margin: 0; }

scale slider, scale slider:hover, scale slider:active {
  min-width: 0; min-height: 0; opacity: 0;
  background: none; background-image: none; box-shadow: none; border: none;
  margin: 0; padding: 0;
}

scale trough { min-width: 10px; border-radius: 10px; background-color: @surface; }
scale highlight { border-radius: 10px; background-color: @secondary; }
CSS

GTK_DATA_PREFIX="$TMPDIR" GTK_THEME="$THEME_NAME" \
yad --scale --hide-value --title="$TITLE" --vertical \
  --min-value=0 --max-value=100 --step=1 --value="$CUR_VOL" \
  --print-partial --no-buttons \
  --width="$WIDTH" --height="$HEIGHT" \
  --on-top --skip-taskbar --undecorated --close-on-unfocus --timeout=0 \
| while read -r v; do [[ "$v" =~ ^[0-9]+$ ]] && pactl set-sink-volume @DEFAULT_SINK@ "${v}%"; done