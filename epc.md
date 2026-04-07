**epc日志等级**  

    storware epc log set level debug
**杀epc进程**  

    ps -ef| grep epc | awk {'print $2'}| xargs kill -9
    umount -l /mnt/j
    mount |grep epc
    ps -ef| grep epc
        
**拿epc堆栈**  

    ps -Tp 36850 |grep udc_io |awk '{print $2}' |xargs -d '\n' -I % sh -c 'pstack %'
**查看epc帮助信息**  

    storware epc help cmds
**epc进程相关文件**  

epc_conf_opt.conf——这个是epc的基本配置参数，包括连接数、绑核参数等；
epc_conf_debug.conf——这个是配置免拷贝内存等级划分的，这个业务一般感知不到；
epc.service——这个是控制epc服务启动的，在这里面指定了启动epc服务需要执行load_epc_module.sh脚本；
load_epc_module.sh——加载内核ko的脚本。



**epc内核开启debug日志**

    echo -n 'module epc +pflmt' > /sys/kernel/debug/dynamic_debug/control
    echo -n 'module epc -pflmt' > /sys/kernel/debug/dynamic_debug/control
**单独开几行日志**  

    echo 'file epc_file.c line 1910 +pflmt' > /sys/kernel/debug/dynamic_debug/control
    echo 'file epc_file.c line 1864 +pflmt' > /sys/kernel/debug/dynamic_debug/control
    dmesg -C ; dmesg -Tw > kernel.log

**epc 开启crc校验方法：**  

    修改配置文件/opt/h3c/etc/conf/default/develop.conf
    [epc_common_crc_split_size, UINT32, 0~4294967295, WRITE-SYNC, 8192][图片]epc内核态生效：
    rmmod epc
    insmod /opt/h3c/bin/epc.ko
    epc用户态生效：
    重启epc

**epc看zmem的占用**
    storware epc show memory-pool stat all

**看普通内存的占用**  

    storware epc show memory
    top -o RES 
    res这一栏是占用的实际物理内存
    bash /opt/h3c/bin/show_hugepages.sh
    看下main-thread有几个1G的，再加上10G，就是zmem公共消耗了多少G的物理内存
    res - zmem多少G，就是普通内存实际占用的物理内存大小

storware epc  udc  dump_cache_info
 **查询trim sleep时间**  

    storware epc show conf module develop  key udc_trim_ult_sleep_utime
 **设置trim sleep时间50ms**  

    storware epc set conf module develop  key udc_trim_ult_sleep_utime value  50000
 
 **查询udc配置文件**
    storware epc udc config_show  
**crash后代码行号定位**  

    root@client14:~# nm /opt/h3c/bin/epc.ko  |grep epc_proc_resend_failed_async
    00000000000085e0 T epc_proc_resend_failed_async
    000000000000868e t epc_proc_resend_failed_async.cold

    root@client14:~# addr2line -e /opt/h3c/bin/epc.ko  -a 0x865c -f -C
    0x000000000000865c
    epc_proc_resend_failed_async
    /jenkins/gitdir/V700R001B01_05201742_0767/debug/product_epc/ud-protocol/epc/epc_kernel/epc_client.c:856

**日志限频**  

    echo  log_rate_limit=50 > /proc/fs/epc/log_rate_limit

**踩内存问题（实际非踩内存）定位结论：**

    epc内核编译选项有-msse等用于控制浮点运算的指令集，sse指令集可以提高某些数学运算和数据处理任务的性能，内核支持sse指令集后内核memset和memcpy等操作会用浮点运算指令集操作来提高性能。
    和os同事交流在同一个核，用户太操作涉及内核上下文切换时，内核浮点型操作会覆盖用户态寄存器，会把用户太指针清除，导致涉及上下文切换的动作不可控，比如calloc申请的内存没有初始化为0。
    epc内核涉及浮点型运算的代码：

    sse经常会被用来加速，会覆盖用户态的寄存器，比如memset（），会把指针清除。memset动作不可控制。

    1，用户线程切换到ko线程（只要涉及到上下文切换，整数操作可能也是浮点指令，会加速优化，性能快一些），寄存器会被清除。---导致原来的用户态操作紊乱。
    2，Linux期望不用浮点型数据。
    3，怎么定位的：做内存操作，共用浮点寄存器，属于浮点模块，也会做其他配套指令，memset和copy指令不会保存。
    查看是否使用浮点型(202408010063)
    objdump -d epc.ko | grep -E 'f(p|ld|st)|%xmm|%ymm'