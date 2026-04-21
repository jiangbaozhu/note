**打印addr对应地址内存，a是打印格式** 

        (gdb) x/[len]a [addr]
        (gdb) x/[N]c [addr]  打印 N 个字符
        (gdb) x/1s [addr]  打印字符串
**以二进制打印addr1~addr2的内存**  

        (gdb) dump binary memory result.bin [addr1] [addr2]

**查看是否asan包**  

        nm -D /opt/h3c/bin/mon |grep malloc
                         U malloc_tag



**模拟RDMA**  

        rdma link add rex0 type rxe netdev ethA3d-0
        rping  -s -a 192.168.182.166 -v -C 10
        rping  -c -a 192.168.182.166 -v -C 10

**清os全部缓存**  

        echo 3 > /proc/sys/vm/drop_caches
**大页进程**  

systemctl status  spdk_huge  

**uds服务 ,gdb忽略SIGPIPE信号**  
        handle SIGPIPE nostop


**可以查看结构体字节**
        readelf -wi /opt/h3c/lib/libudc.so  |less
 



**内蒙古环境inode**  
        10.141.226.50



**查询数据库**  

        /opt/h3c/bin/python3 /opt/h3c/lib/python3.9/site-packages/cm_base/db/util/test_db_status.py test_query_table ud_namespace_cfg


**cas虚拟机**  

        virsh  list
        virsh  reboot  node177
        virsh shutdown node177
        virsh start  node177
        virsh list --all

**strace跟踪所有子进程**  

         strace -f -e trace=file,desc -s 512 -o 0718nfs_milvus_strace.log -p 317631
 
slub
可以执行这个命令添加  grubby --update-kernel=ALL --args="slub_debug=FZPU"   重启生效


**打印协程信息**  

        (gdb) p *(ABTI_xstream *) lp_ABTI_local
        p ((ABTI_xstream*)lp_ABTI_local)->hang_info

**用这个指令可以打印所有线程栈：**  

        ps -eT -o pid,tid --no-headers | xargs -n2 sh -c 'echo "PID: $0  TID: $1"; cat /proc/$0/task/$1/stack 2>/dev/null; echo "----------------------"' 
**配置免密登录**  
        ssh-keygen -t rsa
        ssh-copy-id root@55.99.28.9

**指定网卡抓包**  

        sudo tcpdump -i ib38-1  -w captureib38-1111.pcap  

**corefile**  

        SIGABORT多数为断言/协程自杀/主动abort等；SIGBUS一般为进程运行过程中换动态库导致；SIGSEGV一般为内存越界/非法指针解引用/栈溢出等
        协程自杀core类问题快速定界：
        1. corefile gdb中p ((ABTI_xstream*)lp_ABTI_local)->hang_info，hung超过15次的SIGABORT即为协程自杀
        2. 确认core的时间点前后cpu/内存资源分配情况，有atop看atop，没有atop看uthread和memctl日志

**内存问题**  

        1. 查看进程整体内存情况
        storware 进程名 show memory [unit kb/mb/gb]
        2. 查看进程中各模块内存情况
        storware 进程名 show memory verbose all [unit kb/mb/gb]
        3. 找到内存占用高的模块，查看该模块每个挡位使用内存的情况
        storware 进程名 show memory module 0x1234(十六进制mid) [verbose all] [unit kb/mb/gb]
        找到挡位信息后，根据挡位排查相关结构体，再进一步排查代码
        根据挡位信息，锁定结构体排查范围的方法：readelf -wi /opt/h3c/lib/libudc.so 可以看到每个结构体的byte_size
        readelf -wi /opt/h3c/lib/libudc.so | grep -A20 "DW_TAG_structure_type" | grep -E "(DW_AT_name|DW_AT_byte_size)"
        4. 如果是ult/hrpc/log等基础支撑组件内存高，多半是业务使用方法错误，导致ult堆积，hrpc堆积，log实例堆积等
        5. 查看ult池信息
        storware epc show uthread xstream all # 获取所有xstream
        storware epc show uthread xstream 0x616000000680 # 获取指定xstream下所有pool（xstream地址为上一个命令中ES的值）
        storware epc show uthread blocked_ults_in_pool 0x617000002a80 # 打印指定pool下挂起的ult
        storware epc show uthread blocked_ults_in_pool 0x617000002e00
        storware epc show uthread blocked_ults_in_pool 0x617000003180
        storware epc show uthread blocked_ults_in_pool 0x617000003500
        6. 查看hrpc是否有集中占用，主要通过业务侧日志和hrpc日志确认，短时间内使用rpc过多，hrpc日志会有默认打印（找到例子后补充）
        7. 查看log实例情况
        storware 进程名 show log        

**inode和dn大小**  

        (gdb) print  sizeof(struct udc_inode)
        $1 = 264
        (gdb) print  sizeof(struct udc_dentry)
        $3 = 128
