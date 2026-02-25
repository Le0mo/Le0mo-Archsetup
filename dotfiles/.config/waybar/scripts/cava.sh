#!/bin/bash

# 配置 - 自定义映射关系
# 格式：数值:对应的字符
declare -A CHAR_MAP=(
    [0]="▁"
    [1]="▂"
    [2]="▂▃"   # 两个字符
    [3]="▄"
    [4]="▅"
    [5]="▆"
    [6]="▇█"   # 两个字符
    [7]="▉"
)

BARS=14
CONF="/tmp/waybar_cava_config"

# 计算最大范围（用于 CAVA 配置）
MAX_RANGE=7

# 生成 idle 输出（使用最小字符）
idle_char="${CHAR_MAP[0]}"
idle_output=$(printf "%${BARS}s" | tr " " "x" | sed "s/x/$idle_char/g")

# 生成 Cava 配置
cat > "$CONF" <<EOF
[general]
bars = $BARS
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = $MAX_RANGE
EOF

cleanup() {
    trap - EXIT INT TERM
    pkill -P $$ -f "cava.*$CONF" 2>/dev/null
    echo "$idle_output"
    exit 0
}
trap cleanup EXIT INT TERM

# 自定义转换函数：将 CAVA 的数字转换为指定字符序列
convert_line() {
    local line="$1"
    local result=""
    
    # 移除分号并分割
    line=$(echo "$line" | tr -d ';')
    
    # 遍历每个数字
    for ((i=0; i<${#line}; i++)); do
        num="${line:$i:1}"
        # 只处理数字
        if [[ "$num" =~ [0-7] ]]; then
            result="${result}${CHAR_MAP[$num]}"
        fi
    done
    echo "$result"
}

# 核心检测：是否存在未暂停的音频流
is_audio_active() {
    pactl list sink-inputs 2>/dev/null | grep -q "Corked: no"
}

# 初始状态
echo "$idle_output"

while true; do
    if is_audio_active; then
        if ! pgrep -P $$ -f "cava.*$CONF" >/dev/null; then
            # 启动 CAVA 并通过 while 循环逐行转换
            cava -p "$CONF" 2>/dev/null | while read -r line; do
                convert_line "$line"
            done &
        fi
        sleep 2
    else
        if pgrep -P $$ -f "cava.*$CONF" >/dev/null; then
            pkill -P $$ -f "cava.*$CONF" 2>/dev/null
            wait 2>/dev/null
            echo "$idle_output"
        fi
        timeout 3s pactl subscribe 2>/dev/null | \
            grep --line-buffered -E "sink-input|source-output" | \
            head -n 1 >/dev/null
    fi
done