#!/bin/bash

# ================= 默认配置 =================
# API接口地址，用于下载随机壁纸
API_URL="https://t.alcy.cc/pc/"
# 壁纸保存目录：用户目录下的 Pictures/Wallpapers/api-random-download
SAVE_DIR="$HOME/Pictures/Wallpapers/api-random-download"

# [新增配置] 自动清理时保留最近多少张图片？
KEEP_COUNT=40

# 阈值：宽度小于 2500 (即1080P及以下) 才进行超分，2K/4K 原图直出
UPSCALE_THRESHOLD=2200

# 默认开关状态 (可被参数覆盖)
ENABLE_CLEANUP=true   # 默认清理旧图片
ENABLE_UPSCALE=true   # 默认开启智能超分
SILENT_MODE=false     # 默认开启通知

# ================= 参数解析 =================
# 显示帮助信息
usage() {
    echo "用法: $(basename $0) [-k] [-n] [-s] [-h]"
    echo "  -k  (Keep)    保留模式：不清理旧壁纸"
    echo "  -n  (No Up)   禁用超分：无论分辨率多少，都直接使用原图"
    echo "  -s  (Silent)  静默模式：不发送任何 notify-send 通知"
    echo "  -h  帮助信息"
    exit 0
}

# getopts 解析命令行参数
# opt 变量存储当前选项，OPTARG 存储选项的参数
while getopts "knsh" opt; do
  case $opt in
    k) ENABLE_CLEANUP=false ;;  # -k 参数：不清理旧文件
    n) ENABLE_UPSCALE=false ;;  # -n 参数：禁用超分
    s) SILENT_MODE=true ;;      # -s 参数：静默模式
    h) usage ;;                  # -h 参数：显示帮助
    *) usage ;;                  # 未知参数显示帮助
  esac
done

# ================= 辅助函数 =================

# 统一通知函数，用于发送系统通知
send_notify() {
    # $1: Title, $2: Body, $3: Extra Args (optional)
    if [ "$SILENT_MODE" = false ]; then
        notify-send "$1" "$2" $3
    fi
}

# ================= 主逻辑 =================

# 创建保存目录（如果不存在）
mkdir -p "$SAVE_DIR"
# 生成文件名：wall_时间戳.jpg
RAW_FILENAME="wall_$(date +%s).jpg"
RAW_PATH="${SAVE_DIR}/${RAW_FILENAME}"

# --- 1. 下载模块 (带心跳通知) ---

# 如果非静默模式，启动后台心跳通知 (每8秒提示一次)
if [ "$SILENT_MODE" = false ]; then
    (
        sleep 8  # 先等8秒，如果8秒内下载完成就不显示
        while true; do
            # 发送持续下载中的通知，--replace-id=999 确保通知被同一个ID替换，不会重复弹出
            notify-send "Wallpaper" "Downloading is still in progress..." --expire-time=5000 --icon=drive-harddisk --replace-id=999
            sleep 8  # 每8秒重复一次
        done
    ) &
    NOTIFY_PID=$!  # 保存后台进程的PID，以便后续终止
else
    NOTIFY_PID=""
fi

# 发送开始下载的通知
send_notify "Wallpaper" "Downloading from Alcy..." "--expire-time=5000"

# 设置用户代理，模拟浏览器请求，避免被服务器拒绝
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# 执行下载
# -L: 跟随重定向
# -s: 静默模式，不显示进度
# -A: 设置用户代理
# --connect-timeout 10: 连接超时10秒
# -m 120: 最大下载时间120秒
# -o: 输出文件
curl -L -s -A "$USER_AGENT" --connect-timeout 10 -m 120 -o "$RAW_PATH" "$API_URL"
DOWNLOAD_EXIT_CODE=$?  # 保存curl的退出码

# 下载结束，杀掉通知进程
if [ -n "$NOTIFY_PID" ]; then
    kill "$NOTIFY_PID" 2>/dev/null  # 终止心跳通知进程，忽略错误
    wait "$NOTIFY_PID" 2>/dev/null  # 等待进程完全结束
fi

# 检查下载结果
if [ $DOWNLOAD_EXIT_CODE -ne 0 ]; then
    send_notify "Wallpaper Error" "Download failed (Network/API Error)" "--urgency=critical"
    exit 1
fi

# 校验文件 (大小和类型)
# 检查文件是否存在，且文件大小小于20KB（20480字节）
if [ ! -f "$RAW_PATH" ] || [ "$(wc -c < "$RAW_PATH")" -lt 20480 ]; then
    send_notify "Wallpaper Error" "Download failed (File too small/Invalid)" "--urgency=critical"
    rm -f "$RAW_PATH"  # 删除无效文件
    exit 1
fi

# 使用file命令检测MIME类型
FILE_TYPE=$(file --mime-type -b "$RAW_PATH")
if [[ "$FILE_TYPE" != image/* ]]; then  # 如果不是图片类型
    send_notify "Wallpaper Error" "Not an image file ($FILE_TYPE)" "--urgency=critical"
    rm -f "$RAW_PATH"
    exit 1
fi

# --- 2. 智能超分模块 ---

FINAL_PATH="$RAW_PATH"  # 最终使用的文件路径，默认为原图
MSG_EXTRA=""            # 额外信息，用于通知

if [ "$ENABLE_UPSCALE" = true ]; then
    IMG_WIDTH=0
    # 检查是否安装了ImageMagick的identify命令
    if command -v identify &> /dev/null; then
        IMG_WIDTH=$(identify -format "%w" "$RAW_PATH")  # 获取图片宽度
    fi

    # 条件: (宽度有效) AND (小于阈值) AND (waifu2x存在)
    if [ "$IMG_WIDTH" -gt 0 ] && [ "$IMG_WIDTH" -lt "$UPSCALE_THRESHOLD" ] && command -v waifu2x-ncnn-vulkan &> /dev/null; then
        send_notify "Wallpaper" "Upscaling image..." "--expire-time=2000"
        # 超分后的文件：原文件名但扩展名改为.png
        UPSCALED_PATH="${RAW_PATH%.*}.png"
        
        # 使用waifu2x进行超分辨率
        # -i: 输入文件
        # -o: 输出文件
        # -n 1: 降噪级别1
        # -s 2: 放大倍数2
        if waifu2x-ncnn-vulkan -i "$RAW_PATH" -o "$UPSCALED_PATH" -n 1 -s 2; then
            FINAL_PATH="$UPSCALED_PATH"  # 使用超分后的文件
            MSG_EXTRA="(Upscaled 2x)"    # 标记已超分
            rm "$RAW_PATH"                # 删除原图
        else
            MSG_EXTRA="(Upscale Failed)"  # 超分失败
        fi
    else
        if [ "$IMG_WIDTH" -ge "$UPSCALE_THRESHOLD" ]; then
            MSG_EXTRA="(Original High-Res)"  # 原图已经是高分辨率
        else
            MSG_EXTRA="(Original)"            # 原图（可能因为宽度信息无效或waifu2x未安装）
        fi
    fi
else
    MSG_EXTRA="(Upscale Disabled)"  # 超分被禁用
fi

# --- 3. 应用模块 ---

# 使用swww设置壁纸（Wayland环境的动态壁纸设置器）
# --transition-duration 2: 过渡动画持续时间2秒
# --transition-type center: 从中心扩散的过渡效果
# --transition-fps 60: 过渡动画60fps
swww img "$FINAL_PATH" --transition-duration 2 --transition-type center --transition-fps 60

# --- 4. 壁纸复制到指定目录 ---
# 复制一份壁纸到指定目录，保持原文件名
BACKUP_DIR="/home/le0mo/Pictures/Wallpapers"
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# 获取文件名（不带路径）
FILENAME=$(basename "$FINAL_PATH")
# 复制文件到备份目录
cp "$FINAL_PATH" "${BACKUP_DIR}/${FILENAME}"
if [ $? -eq 0 ]; then
    send_notify "Wallpaper" "Copied to backup directory" "--expire-time=2000"
fi

# --- 5. 钩子与清理 ---
# 在后台执行清理和其他脚本，不阻塞主流程
(
    # 钩子脚本屏蔽标准输出，保留报错
    # 检查并执行matugen主题更新脚本（用于根据壁纸生成颜色主题）
    [ -x "$HOME/.config/scripts/matugen-update.sh" ] && "$HOME/.config/scripts/matugen-update.sh" "$FINAL_PATH" > /dev/null
    
    sleep 0.5  # 短暂延迟，避免资源竞争
    
    # 检查并执行niri窗口管理器的背景模糊脚本
    [ -x "$HOME/.config/scripts/niri_set_overview_blur_dark_bg.sh" ] && "$HOME/.config/scripts/niri_set_overview_blur_dark_bg.sh" > /dev/null
    
    # [修改] 动态清理逻辑
    if [ "$ENABLE_CLEANUP" = true ]; then
        # 计算需要从第几行开始删除 (保留数量 + 1)
        DELETE_START=$((KEEP_COUNT + 1))
        # cd到保存目录，按时间排序（最新的在前），删除超过保留数量的旧文件
        # ls -t: 按修改时间排序，最新的在前
        # tail -n +$DELETE_START: 从第DELETE_START行开始输出（即跳过前KEEP_COUNT个）
        # xargs -I {} rm -- {}: 对每个文件执行删除操作，2>/dev/null忽略错误（如文件不存在）
        cd "$SAVE_DIR" && ls -t | tail -n +$DELETE_START | xargs -I {} rm -- {} 2>/dev/null
    fi
) &  # & 表示在后台执行

# 发送最终成功通知
send_notify "Wallpaper Updated" "Enjoy! $MSG_EXTRA"