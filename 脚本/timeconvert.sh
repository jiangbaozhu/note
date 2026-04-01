#!/bin/bash

# 默认配置
DEFAULT_USER="stor_user"
DEFAULT_PASS="Admin@123stor"
SSH_TIMEOUT=5

# 使用方法
usage() {
    echo "Usage: $0 [-u username] [-p password] <target_node> <reference_time>"
    echo "Options:"
    echo "  -u, --user <username>   SSH username (default: $DEFAULT_USER)"
    echo "  -p, --pass <password>   SSH password (default: $DEFAULT_PASS)"
    echo "Time format:"
    echo "  YYYY-MM-DD HH:MM:SS     (e.g. 2023-08-15 14:30:00)"
    echo "  now                     (current time)"
    echo "Examples:"
    echo "  $0 192.168.1.101 \"2023-08-15 14:30:00\""
    echo "  $0 -u myuser -p mypass 192.168.1.101 now"
    exit 1
}

# 将秒数转换为HH:MM:SS格式
sec_to_hms() {
    local seconds=$1
    local sign=""
    
    # 处理负数情况
    if [[ $seconds -lt 0 ]]; then
        sign="-"
        seconds=$(( -seconds ))
    fi
    
    local hours=$(( seconds / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$(( seconds % 60 ))
    
    printf "%s%02d:%02d:%02d" "$sign" $hours $minutes $secs
}

# 参数解析
USER="$DEFAULT_USER"
PASS="$DEFAULT_PASS"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user)
            USER="$2"
            shift 2
            ;;
        -p|--pass)
            PASS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "ERROR: Unknown option $1"
            usage
            ;;
        *)
            if [[ -z "$TARGET_NODE" ]]; then
                TARGET_NODE="$1"
            else
                REFERENCE_TIME="$1"
            fi
            shift
            ;;
    esac
done

# 参数验证
if [[ -z "$TARGET_NODE" || -z "$REFERENCE_TIME" ]]; then
    echo "ERROR: Both target node and reference time are required!"
    usage
fi

# 获取时间戳（秒）
get_timestamp() {
    if [[ "$1" == "now" ]]; then
        date +%s
    else
        date -d "$1" +%s 2>/dev/null
    fi
}

# 获取远程时间戳
get_remote_timestamp() {
    local node="$1"
    sshpass -p "$PASS" ssh -n -o StrictHostKeyChecking=no \
        -o ConnectTimeout=$SSH_TIMEOUT \
        $USER@$node "date +%s" 2>/dev/null
}

# 计算时间差（带网络延迟补偿）
calculate_time_diff() {
    local node="$1"
    local local_start=$(date +%s)
    local remote_time=$(get_remote_timestamp "$node")
    local local_end=$(date +%s)
    
    if [[ -z "$remote_time" ]]; then
        echo "ERROR: Unable to get time from $node"
        exit 1
    fi
    
    # 计算网络延迟补偿（取RTT的一半）
    local rtt=$(( (local_end - local_start) / 2 ))
    echo $(( remote_time - local_start + rtt ))
}

# 主程序
REFERENCE_TIMESTAMP=$(get_timestamp "$REFERENCE_TIME")

if [[ -z "$REFERENCE_TIMESTAMP" ]]; then
    echo "ERROR: Invalid time format. Use 'YYYY-MM-DD HH:MM:SS' or 'now'"
    exit 1
fi

TIME_DIFF=$(calculate_time_diff "$TARGET_NODE") || exit 1

# 计算目标节点对应时间
TARGET_TIMESTAMP=$(( REFERENCE_TIMESTAMP + TIME_DIFF ))
TARGET_TIME=$(date -d "@$TARGET_TIMESTAMP" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)

# 格式化输出
FORMATTED_DIFF=$(sec_to_hms $TIME_DIFF)
LOCAL_TIME_FORMATTED=$(date -d "@$REFERENCE_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")

# 输出结果
echo "┌───────────────────────┬───────────────────────┐"
printf "│ %-21s │ %-21s │\n" "Local reference time" "$LOCAL_TIME_FORMATTED"
echo "├───────────────────────┼───────────────────────┤"
printf "│ %-21s │ %-21s │\n" "Target node time" "$TARGET_TIME"
echo "├───────────────────────┼───────────────────────┤"
printf "│ %-21s │ %-21s │\n" "Time difference" "$FORMATTED_DIFF"
echo "└───────────────────────┴───────────────────────┘"
