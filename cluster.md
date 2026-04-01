
__集群状态检查__  

    storware mon osd show diskpool all #查询硬盘池信息
    storware mon osd show pool all #查询存储池信息
    storware mon engine cli engine dump #查询引擎状态
    storware mon get mon_status #查询mon状态
    ps -ef | grep dpe

__查询memory-pool__  

    storware dpe show memory-pool stat all

__重启配置流__  

    supervisorctl restart ud-leader
__hrpc帮助信息__  

    storware dpe help hrpc
__安装部署失败日志__  

    /var/log/shell_util/package.log

__过滤hos超时op__  

    zgrep  -E "cost [1-9][0-9]{3,}" hos.client.epc.log-20241012-223*
    grep -E "cost [1-9][0-9]{3,}"  /var/log/storage/hos/ 

__两节点部署__  

    1.安装大包
    2.vim /opt/h3c/etc/storware.conf

    # 单集群的最小节点数量
    min_node_num_per_cluster = 3
    # 单节点池的最小节点数量
    min_node_num_per_node_pool = 3

    这两个值都改成2
    3.supervisorctl restart cm-leader，然后登陆handy开始部署即可（注意：需要先重启进程再登录handy）

onestor resctl  show  config  
__下一代升级问题__  

    状态文件：  记录当前升级状态及失败原因
                    /opt/upd/updconf/step_state.conf
    配置文件：   记录升级中的配置信息，包括节点角色、地址、安装包信息等
                    /opt/upd/updconf/layer.conf
    终端日志：   记录升级流程的日志
                    /var/log/upgrade/console_print.log
    shell相关日志：  记录shell脚本日志
                    /var/log/upgrade/upgrade_sh.log
    python相关日志： 服务端收到请求的执行日志都在UPDS，客户端发送的请求的日志都在UPDC
                    /var/log/storage/UPDC/UPDC.log      客户端日志
                    /var/log/storage/UPDS/UPDS.log       服务段日志
                    
    问题分析定位方法：
                    1、查看终端日志console_print.log，确定问题出现得时间
                    2、查看状态文件step_state.conf，明确问题节点、出现问题所处得状态以及可能得原因
                    3、查看主handy节点得UPDC日志，进一步缩小问题时间点
                    4、查看问题节点的UPDS日志，分析具体原因

__查看engine启动状态__
    storware  dpe eng_ctrl engine_detail_status

**全组件开日志**

        storware mode dev enable

        storware-dev self_node set log level debug

storware resctl show  quota

**关CRC:**  

    创池前执行的：
    sudo echo "pool_crc_level=1" | sudo tee -a /opt/h3c/etc/conf/storware_basic/basic.conf    
    sudo systemctl restart  mon
    sudo systemctl restart  dpe

    
**同版本升级**  

    1.主备节点/etc/storware/storware.conf下same_ver_upgrade = no的配置项改为 same_ver_upgrade = yes，然后重启下服务supervisorctl  restart  all

    2.然后在重启apache2服务：  service  apache2  restart即可

    直接用coredumpctl gdb加pid就可以打开corefile

**集群销毁**  

    sudo storware-cli probe
    sudo storware-cli destroy --y
    强制销毁
    storware-cli destroy -iqn --y

    单节点销毁
    storware-cli destroy --host 10.121.29.191 --y  
**mds开日志**  

    storware mon fs dump先找到mds对应的元数据池id  然后for i in {0..100};do sudo storware dpe eng_ctrl loglevel engine 4.$i module MDS level 6;done  
**HOS打桩**  

    sudo storware epc set hos_fault name engine_error switch on inject_err -110//不取消的话就会再hos的超时时间内重试
**mds修改配置**  

    storware mode dev enable && storware-dev dpe set conf module develop key mds_mix_rd_cache_switch value true
    storware mode dev enable && storware-dev dpe set conf module develop key mds_mix_rd_cache_switch value true
**vip迁移**  
  
storware mon vip assign vip {10.125.64.80} node {node82}