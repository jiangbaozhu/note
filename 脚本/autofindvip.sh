#!/bin/bash

# 默认配置
CONFIG_FILE="/opt/h3c/etc/conf/storware_basic/basic.conf"
DEFAULT_LOG_FILE="/var/log/devmgr/devmgrd"
USER="stor_user"
PASSWORD="Admin@123stor"
SSH_TIMEOUT=5

# 使用方法
usage() {
    echo "Usage: $0 [-c config_file] [-l log_file] <target_ip>"
    echo "Options:"
    echo "  -c, --config <path>   Specify config file (default: $CONFIG_FILE)"
    echo "  -l, --log <path>      Specify log file path (default: $DEFAULT_LOG_FILE)"
    echo "Example:"
    echo "  $0 -l /var/log/alt.log 10.121.24.94"
    exit 1
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
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
            TARGET_IP="$1"
            shift
            ;;
    esac
done

# 设置默认日志路径
LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_FILE}"

# 参数验证
if [[ -z "$TARGET_IP" ]]; then
    echo "ERROR: Target IP is required!"
    usage
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "ERROR: Config file $CONFIG_FILE not found!"
    exit 1
fi

# 从配置文件提取管理IP（兼容逗号和空格分隔）
extract_ips() {
    local ips_line=$(grep '^sys_all_manage_ip' "$CONFIG_FILE" | cut -d= -f2 | tr -d '{}' | tr ',' ' ')
    echo "$ips_line"
}

# 获取节点列表
NODES=($(extract_ips))

if [[ ${#NODES[@]} -eq 0 ]]; then
    echo "ERROR: No manage IPs found in config file!"
    exit 1
fi

# 本地查询函数
local_query() {
    echo "==== Local Host [Log: ${LOG_FILE/#$HOME/~}] ===="
    if [[ -f "$LOG_FILE" ]]; then
        grep -E "IP_ADD.*$TARGET_IP|IP_DEL.*$TARGET_IP" "$LOG_FILE" 2>/dev/null || \
        echo "No matching records found"
    else
        echo "ERROR: Log file not found!"
    fi
    echo "=============================================="
    echo ""
}

# 远程查询函数
remote_query() {
    local node="$1"
    echo "==== Node $node [Log: ${LOG_FILE/#$HOME/~}] ===="
    sshpass -p "$PASSWORD" ssh -n -o StrictHostKeyChecking=no \
        -o ConnectTimeout=$SSH_TIMEOUT \
        $USER@$node \
        "if [[ -f '$LOG_FILE' ]]; then
            grep -E 'IP_ADD.*$TARGET_IP|IP_DEL.*$TARGET_IP' '$LOG_FILE' 2>/dev/null || \
            echo 'No matching records found'
         else
            echo 'ERROR: Log file not found!'
         fi"
    echo "=============================================="
    echo ""
}

# 执行查询
#local_query
for node in "${NODES[@]}"; do
    remote_query "$node"
done
# 并行查询所有节点
#for node in "${NODES[@]}"; do
#    remote_query "$node" &
#done

#wait
