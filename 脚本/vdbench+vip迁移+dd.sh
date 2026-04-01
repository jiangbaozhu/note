#!/bin/bash
set -e  # 建议添加：遇到错误立即退出

WORK_DIR="/mnt/jbz/test1/vdb.1_1.dir"  # vdbench工作目录（不删除）
VDbench_PATH="/root/vdbench50403/vdbench"        # vdbench命令路径
VDBENCH_CFG="/root/vdbench50403/jbz"
target_node1="E6-64-node98"
target_node2="E6-64-node96"
target_ip="55.108.84.98"
vip="55.108.84.192"
SSH_USER="stor_user"               # SSH登录用户名
SSH_PASS="Admin@123stor"  # SSH登录密码

# 全局变量存储PID
declare -g LAST_VDBENCH_PID=""

function run_vdbench() {
    echo "执行vdbench配置文件：${VDBENCH_CFG}"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_file="vdbench_output_${timestamp}.log"
    echo "输出文件: ${output_file}"

    if [[ "$1" == "bg" || "$1" == "&" ]]; then
        ${VDbench_PATH} -f ${VDBENCH_CFG} -o ${timestamp} > "${output_file}" 2>&1 &
        LAST_VDBENCH_PID=$!
        echo "===== vdbench后台执行中，PID: ${LAST_VDBENCH_PID} ====="
    else
        ${VDbench_PATH} -f ${VDBENCH_CFG} -o ${timestamp} > "${output_file}" 2>&1
        echo "===== vdbench文件生成完成 ====="
    fi
}

function run_vdbench_vr() {
    echo "-vr执行vdbench配置文件：${VDBENCH_CFG}"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local output_file="vdbench_vr_output_${timestamp}.log"  # 修改文件名避免冲突
    echo "输出文件: ${output_file}"

    if [[ "$1" == "bg" || "$1" == "&" ]]; then
        ${VDbench_PATH} -f ${VDBENCH_CFG} -vr -o ${timestamp} > "${output_file}" 2>&1 &
        LAST_VDBENCH_PID=$!
        echo "=====-vr vdbench后台执行中，PID: ${LAST_VDBENCH_PID} ====="
    else
        ${VDbench_PATH} -f ${VDBENCH_CFG} -vr -o ${timestamp} > "${output_file}" 2>&1
        echo "=====-vr vdbench文件生成完成 ====="
    fi
}

function wait_vdbench() {
    if [[ -n "$LAST_VDBENCH_PID" ]]; then
        echo "等待vdbench进程 ${LAST_VDBENCH_PID} 完成..."
        if wait $LAST_VDBENCH_PID; then
            echo "vdbench进程执行完成"
        else
            echo "警告：vdbench进程异常退出"
        fi
        LAST_VDBENCH_PID=""
    else
        echo "没有正在运行的vdbench进程"
    fi
}

function run_dd_read() {
    echo "===== 开始执行dd读取文件 ====="

    # 检查目录是否存在
    if [[ ! -d "${WORK_DIR}" ]]; then
        echo "错误：工作目录 ${WORK_DIR} 不存在！"
        exit 1
    fi

    # 遍历工作目录下的文件
    local files_found=false

    for FILE in "${WORK_DIR}"/vdb*; do
        if [[ -f "${FILE}" ]]; then
            files_found=true
            #echo "读取文件：${FILE}"
            dd if="${FILE}" of=/dev/null bs=1M 2>/tmp/dd_read.log
        fi
    done

    if [[ "${files_found}" == "false" ]]; then
        echo "错误：未找到vdbench生成的文件！"
        exit 1
    fi

    echo "===== dd读取文件完成 ====="
}

# 主流程
echo "====  1、单客户端预埋数据  ===="
run_vdbench
wait_vdbench  # 等待预埋数据完成

echo "====  2、单客户端持续读 读优先sync。写优先excl，混合优先mix==="
run_dd_read

echo "====  3、单客户端混合读写vr 读优先sync->excl  ===="
run_vdbench_vr bg  # 使用bg参数而不是&
sleep 3  # 给vdbench一点启动时间

echo "====  4、构造多客户端混合读写时，迁移vip，excl->mix===="
bash ./epc/udc_cache_test1.sh
sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no \
    "${SSH_USER}@${target_ip}" \
    "sudo storware mon vip assign vip ${vip} node ${target_node1}"

echo "====  5、sleep 60s cap淘汰后，即为单客户端混合读写 mix->sync===="
sleep 60

echo "====  6、run_dd_read  mix->sync===="
run_dd_read

echo "====  7、构造多客户端混合读写时，迁移vip，sync>mix===="
# 确保之前的vdbench已完成
wait_vdbench

# 启动新的vdbench测试
run_vdbench_vr bg
sleep 3  # 等待vdbench启动

sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no \
    "${SSH_USER}@${target_ip}" \
    "sudo storware mon vip assign vip ${vip} node ${target_node2}"

echo "====  8、单客户端持续读 mix->sync。==="
sleep 60
run_dd_read

echo "====  9、单客户端混合读写vr 读优先sync->excl  ===="
# 确保之前的vdbench已完成
wait_vdbench
run_vdbench_vr

echo "==== 所有测试步骤已启动 ===="
