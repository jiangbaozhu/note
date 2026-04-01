
__挂载nfs__  

    mount -t nfs -o vers=3,  10.121.29.193:/nfs_jbz /jbz

    
__查看nfs导出目录是否存在__  

    storware uds  nfs  show_export export_id 3
    cat /opt/h3c/etc/uds/export.conf
    失败的导出目录
    grep "\/test2\/dir2" nfs.log
    2024-10-16 20:47:53.595832 30b0 7f061cd40640 ERROR [EXPORT][init_export_root:2052][0] Lookup failed on path, ExportId=3Path=/test2/dir2 FSAL_ERROR=(File busy, retry,110)

**nfs长时间掉零，排查客户端和服务端连通性**  

    开日志
    rpcdebug -m nfs -s all
    rpcdebug -m rpc -s all

    dmesg -C;dmesg -Tw
    关日志
    rpcdebug -m rpc -c all
    rpcdebug -m nfs -c all

    telent 服务端ip 2049 
    telnet 182.203.11.233 2049
    ping  vip

**nfs主线允许实ip挂载：**  

    storware uds nfs_inject inflight_op switch off
**nfs B01实ip挂载方式**  

    1、stop uds
    2、gdb 
    3、b nfs_init
    4、r
    5、(gdb) set variable inflight_op_switch=0
    (gdb) p inflight_op_switch
    $1 = false
**nfs perf分析**  

    zgrep -aE "Timestamp|nfs_proc_process" /var/log/storage/perf/perf_inc_output_uds.log |less
    zgrep -aE "engine_opproc_handler|Timestamp" /var/log/storage/perf/perf_inc_output_dpe.log |less

**udc读缓存桩点**

    storware uds show fault_inject |grep TP_UDC_FC
    storware uds set fault_inject index 5660 switch off

**udc读缓存信息**  

    watch -d -n 1 "storware uds udc fc_mem_dump"
**udc设置淘汰水位**  
    storware-dev uds set conf module develop key udc_fc_free_watermark_low value 90
    storware-dev uds set conf module develop key udc_fc_free_watermark_min value 90
