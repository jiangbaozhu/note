__打印addr对应地址内存，a是打印格式__ 

        (gdb) x/[len]a [addr]
        (gdb) x/[N]c [addr]  打印 N 个字符
        (gdb) x/1s [addr]  打印字符串
__以二进制打印addr1~addr2的内存__  

        (gdb) dump binary memory result.bin [addr1] [addr2]

__查看是否asan包__  

        nm -D /opt/h3c/bin/mon |grep malloc
                         U malloc_tag



__模拟RDMA__  

        rdma link add rex0 type rxe netdev ethA3d-0
        rping  -s -a 192.168.182.166 -v -C 10
        rping  -c -a 192.168.182.166 -v -C 10

__清os全部缓存__  

        echo 3 > /proc/sys/vm/drop_caches
__大页进程__  

systemctl status  spdk_huge  

__uds服务 ,gdb忽略SIGPIPE信号__  
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
