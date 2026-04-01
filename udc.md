
**udc读缓存桩点**

    storware uds show fault_inject |grep TP_UDC_FC
    storware uds set fault_inject index 5660 switch off

**udc读缓存信息**  

    watch -d -n 1 "storware uds udc fc_mem_dump"
**udc设置淘汰水位**  

    storware-dev uds set conf module develop key udc_fc_free_watermark_low value 90
    storware-dev uds set conf module develop key udc_fc_free_watermark_min value 90

 **查询udc配置文件**  

    storware epc udc config_show 
**查看dn/inode缓存**  

    storware epc  udc  dump_cache_info

 **查询trim sleep时间**  

    storware epc show conf module develop  key udc_trim_ult_sleep_utime
 **设置trim sleep时间50ms**  

    storware epc set conf module develop  key udc_trim_ult_sleep_utime value  50000