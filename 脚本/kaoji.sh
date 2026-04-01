#!/bin/bash

# ============================================
# EPC并发重叠I/O测试脚本
# 测试场景：两个客户端并发读写同一文件
# 日期：2026-02-12
# ============================================

# 配置参数
CLIENT_A="55.108.95.215"
CLIENT_B="55.99.28.9"
TEST_USER="root"  # 根据实际情况修改
TEST_DIR="/mnt/nfs"
TEST_FILE="${TEST_DIR}/epc_test_file.bin"
ITERATIONS=100    # 测试迭代次数
LOG_DIR="./test_logs"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 远程执行命令
remote_exec() {
    local host=$1
    local cmd=$2
    ssh ${SSH_OPTS} ${TEST_USER}@${host} "$cmd"
    return $?
}

# 检查远程文件MD5
get_remote_md5() {
    local host=$1
    local file=$2
    remote_exec ${host} "md5sum ${file} 2>/dev/null | awk '{print \$1}'"
}

# 生成随机区间
generate_random_range() {
    local max_size=$((100 * 1024 * 1024))  # 100MB最大文件
    local write_size_a=$(( (RANDOM % 4000 + 50) * 1024 ))  # 50K-4M
    local start_a=$(( RANDOM % (max_size - write_size_a) ))
    local end_a=$((start_a + write_size_a))
    
    local write_size_b=$(( (RANDOM % 10000 + 65) * 1024 ))  # 65K-10M
    local start_b=$(( RANDOM % (max_size - write_size_b) ))
    local end_b=$((start_b + write_size_b))
    
    local read_size=$(( (RANDOM % 20 + 5) * 1024 ))  # 5K-25K
    local read_start=$(( RANDOM % (max_size - read_size) ))
    local read_end=$((read_start + read_size))
    
    echo "${start_a}:${end_a}:${start_b}:${end_b}:${read_start}:${read_end}"
}

# 清理函数
cleanup() {
    log_info "执行清理操作..."
    
    # 删除测试文件
    remote_exec ${CLIENT_A} "rm -f ${TEST_FILE} 2>/dev/null"
    remote_exec ${CLIENT_B} "rm -f ${TEST_FILE} 2>/dev/null"
    
    # 检查是否有core文件
    local core_a=$(remote_exec ${CLIENT_A} "find /tmp /var/tmp -name 'core*' -o -name '*.core' 2>/dev/null | head -5")
    local core_b=$(remote_exec ${CLIENT_B} "find /tmp /var/tmp -name 'core*' -o -name '*.core' 2>/dev/null | head -5")
    
    if [ -n "$core_a" ] || [ -n "$core_b" ]; then
        log_warn "发现core文件:"
        [ -n "$core_a" ] && echo "客户端A: $core_a"
        [ -n "$core_b" ] && echo "客户端B: $core_b"
    fi
    
    # 检查EPC进程状态
    local epc_a=$(remote_exec ${CLIENT_A} "ps aux | grep -E '[e]pc' | wc -l")
    local epc_b=$(remote_exec ${CLIENT_B} "ps aux | grep -E '[e]pc' | wc -l")
    
    log_info "EPC进程状态 - 客户端A: ${epc_a}, 客户端B: ${epc_b}"
}

# 单个测试迭代
run_test_iteration() {
    local iteration=$1
    local ranges=$2
    
    # 解析区间参数
    IFS=':' read -r start_a end_a start_b end_b read_start read_end <<< "$ranges"
    
    log_info "开始第${iteration}次迭代"
    log_info "区间配置: A写[${start_a}-${end_a}] B写[${start_b}-${end_b}] A读[${read_start}-${read_end}]"
    
    # 1. 清理旧文件
    remote_exec ${CLIENT_A} "rm -f ${TEST_FILE}"
    remote_exec ${CLIENT_B} "rm -f ${TEST_FILE}"
    
    # 2. 客户端A创建并写入数据
    log_info "客户端A写入数据..."
    remote_exec ${CLIENT_A} "
        dd if=/dev/urandom of=${TEST_FILE} bs=1 count=$((end_a - start_a)) seek=${start_a} 2>/dev/null
    " &
    local pid_a_write=$!
    
    # 3. 客户端B重叠覆盖写入
    sleep 0.1  # 稍微延迟确保A先开始
    log_info "客户端B重叠写入..."
    remote_exec ${CLIENT_B} "
        dd if=/dev/urandom of=${TEST_FILE} bs=1 count=$((end_b - start_b)) seek=${start_b} 2>/dev/null
    " &
    local pid_b_write=$!
    
    # 4. 客户端A在B写入时进行空读
    sleep 0.2  # 确保写入已经开始
    log_info "客户端A并发读取..."
    remote_exec ${CLIENT_A} "
        dd if=${TEST_FILE} of=/dev/null bs=1 count=$((read_end - read_start)) skip=${read_start} 2>/dev/null
    "
    
    # 等待写入完成
    wait $pid_a_write $pid_b_write
    log_info "写入操作完成"
    
    # 5. 同步文件系统
    remote_exec ${CLIENT_A} "sync"
    remote_exec ${CLIENT_B} "sync"
    sleep 1
    
    # 6. 比较MD5
    log_info "比较文件MD5..."
    local md5_a=$(get_remote_md5 ${CLIENT_A} ${TEST_FILE})
    local md5_b=$(get_remote_md5 ${CLIENT_B} ${TEST_FILE})
    
    if [ "$md5_a" = "$md5_b" ] && [ -n "$md5_a" ]; then
        log_info "MD5一致: ${md5_a}"
    else
        log_error "MD5不一致! 客户端A: ${md5_a}, 客户端B: ${md5_b}"
        
        # 记录详细信息
        echo "=== 第${iteration}次迭代失败 ===" >> ${LOG_DIR}/failure_details.log
        echo "区间: $ranges" >> ${LOG_DIR}/failure_details.log
        echo "MD5_A: $md5_a" >> ${LOG_DIR}/failure_details.log
        echo "MD5_B: $md5_b" >> ${LOG_DIR}/failure_details.log
        
        # 保存文件大小信息
        remote_exec ${CLIENT_A} "ls -lh ${TEST_FILE}" >> ${LOG_DIR}/failure_details.log
        remote_exec ${CLIENT_B} "ls -lh ${TEST_FILE}" >> ${LOG_DIR}/failure_details.log
        
        return 1
    fi
    
    # 7. truncate文件为0
    log_info "截断文件..."
    remote_exec ${CLIENT_A} "truncate -s 0 ${TEST_FILE}"
    remote_exec ${CLIENT_B} "sync"
    
    # 8. 验证truncate结果
    local size_a=$(remote_exec ${CLIENT_A} "stat -c%s ${TEST_FILE} 2>/dev/null || echo 'error'")
    if [ "$size_a" = "0" ]; then
        log_info "文件截断成功"
    else
        log_warn "文件截断后大小不为0: ${size_a}"
    fi
    
    return 0
}

# 主函数
main() {
    # 创建日志目录
    mkdir -p ${LOG_DIR}
    
    log_info "开始EPC并发重叠I/O测试"
    log_info "客户端A: ${CLIENT_A}"
    log_info "客户端B: ${CLIENT_B}"
    log_info "测试目录: ${TEST_DIR}"
    log_info "迭代次数: ${ITERATIONS}"
    
    # 检查客户端连通性
    log_info "检查客户端连通性..."
    if ! remote_exec ${CLIENT_A} "echo 'Connected to A'"; then
        log_error "无法连接到客户端A"
        exit 1
    fi
    
    if ! remote_exec ${CLIENT_B} "echo 'Connected to B'"; then
        log_error "无法连接到客户端B"
        exit 1
    fi
    
    # 检查测试目录
    log_info "检查测试目录..."
    remote_exec ${CLIENT_A} "mkdir -p ${TEST_DIR}"
    remote_exec ${CLIENT_B} "mkdir -p ${TEST_DIR}"
    
    # 记录开始时间
    local start_time=$(date +%s)
    local success_count=0
    local failure_count=0
    
    # 执行测试迭代
    for ((i=1; i<=ITERATIONS; i++)); do
        # 生成随机区间
        local ranges=$(generate_random_range)
        
        # 运行测试
        if run_test_iteration $i "$ranges"; then
            success_count=$((success_count + 1))
            echo "第${i}次迭代: 成功" >> ${LOG_DIR}/results.log
        else
            failure_count=$((failure_count + 1))
            echo "第${i}次迭代: 失败" >> ${LOG_DIR}/results.log
            
            # 可选：失败后暂停检查
            read -p "测试失败，按Enter继续，或Ctrl+C退出..."
        fi
        
        # 每10次迭代输出进度
        if (( i % 10 == 0 )); then
            log_info "进度: ${i}/${ITERATIONS}, 成功: ${success_count}, 失败: ${failure_count}"
        fi
    done
    
    # 记录结束时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 生成测试报告
    log_info "测试完成，生成报告..."
    cat > ${LOG_DIR}/test_report.txt << EOF
EPC并发重叠I/O测试报告
=======================
测试时间: $(date)
持续时间: ${duration}秒
迭代次数: ${ITERATIONS}
成功次数: ${success_count}
失败次数: ${failure_count}
成功率: $((success_count * 100 / ITERATIONS))%

客户端信息:
- 客户端A: ${CLIENT_A}
- 客户端B: ${CLIENT_B}
- 测试目录: ${TEST_DIR}

测试场景:
1. 客户端A写入随机区间(50K-4M)
2. 客户端B重叠写入随机区间(65K-10M)
3. 客户端A在B写入时读取随机区间(5K-25K)
4. 比较两端MD5
5. Truncate文件为0
6. 重复执行，区间随机

EOF
    
    # 最终清理
    cleanup
    
    log_info "测试报告已保存至: ${LOG_DIR}/test_report.txt"
    log_info "详细日志请查看: ${LOG_DIR}/ 目录"
    
    if [ ${failure_count} -eq 0 ]; then
        log_info "所有测试用例通过！"
        exit 0
    else
        log_warn "存在${failure_count}个失败用例，请检查日志"
        exit 1
    fi
}

# 异常处理
trap 'log_error "脚本被中断"; cleanup; exit 1' INT TERM

# 运行主函数
main
