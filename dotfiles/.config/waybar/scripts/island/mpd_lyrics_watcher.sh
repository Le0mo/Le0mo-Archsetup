#!/bin/bash
#!/usr/bin/env bash
set -euo pipefail

FETCHER="/home/le0mo/.config/waybar/scripts/island/lyrics_fetcher.py"

# 等待 MPD 就绪（开机时 mpd 可能还没起来）
until mpc -q status >/dev/null 2>&1; do
  sleep 1
done

# 记住上一首，避免同一次状态抖动触发重复抓取
last_key=""

while true; do
  # 阻塞等待：player 子系统变化（换歌/暂停/继续/seek）
  mpc -q idle player >/dev/null 2>&1 || { sleep 1; continue; }

  # 只在“歌曲变了”才执行
  # mpc -f 输出为：artist|||title（没有 artist 也能工作）
  key="$(mpc -f '%artist%|||%title%' current 2>/dev/null || true)"
  key="${key//$'\n'/}"

  [[ -z "${key}" ]] && continue
  [[ "${key}" == "${last_key}" ]] && continue
  last_key="${key}"

  # 触发抓取（脚本内部会判断：本地已有歌词就跳过）
  "${FETCHER}" >/dev/null 2>&1 || true
done