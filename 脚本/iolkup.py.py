import sys
import os
import re
import gzip

def print_help():
    print("\n用法: python iolkup.py [offset] [inode] [file]\n")
    print("    offset:  数据不一致的偏移,如果输入16进制，需要增加0x")
    print("             如何查找offset可以通过 python3 iolkup.py help offset 查看帮助\n")
    print("    inode:   数据不一致的文件inode,如果输入16进制，需要增加0x")
    print("             如何查找文件inode可以通过 python3 iolkup.py help inode 查看帮助\n")
    print("    file:    要过滤的日志，只能输入udc和hos的日志，压缩非压缩都可以，可以通过*来过滤多个文件")
    print("             具体用法可以通过 python3 iolkup.py help file 查看")
    print("")

def print_vdbench3():
    print("vdbench50403:")
    print("    00:17:38.956 messages: dvpost: /mnt/hwl_nfs_1/clientl/vdb.1_1.dir/vdb.2_1.dir/vdb.3_1.dir/vdb_f0013.file fsdl fsdl 0X00023800 0x00014c00 1024 0x0 0x62a2c39989273 0x14 0xl 0x32 0X0 0 36028797018963971")
    print("    00:17:38.956 messages:")
    print("    00:17:38.956 messages:         Data Validation error for fsd=fsdl; FSD lba: 0x00038400; DV xfersize: 1024； relative sector in block: 0x00 ( 0)")
    print("    00:17:38.956 messages:         File name: /mnt/hwl_nfs_1/client1/vdb.1_1.dir/vdb.2_1.dir/vdb.3_1.dir/vdb_f0013.file; file lba: 0x00014c00")
    print("    00:17:38.956 messages:         ===> Logical byte address miscompare.")
    print("    00:17:38.956 messages:         Data miscompare.")
    print("    00:17:38.956 messages:         The sector below was written Thursday, December 26， 2024 21:21:33.491 CST")
    print("    00:17:38.956 messages: 0x000*  00000000 00038400 ........ ........   00000000 01d54c00 00062a2c 39989273")
    print("    00:17:38.956 messages: 0x010   01..0000 66736431 20202020 00000000   01320000 31647366 20202020 00000000")

def print_vdbench6():
    print("vdbench50406:")
    print("    14:05:49.361 Corrupted data block for fsd=fsd2,file=/mnt/test1/client2/133/vdb.1_7.dir/vdb_f0054.file; file lba: 0x2550000 xfersize=1048576")
    print("    14:05:49.361")
    print("    14:05:49.361 Data block has 256 key block(s) of 4096 bytes each.")
    print("    14:05:49.361 4 of 256 key blocks are corrupted.")
    print("    14:05:49.362 Key block lba: 0x28e55dc000")
    print("    14:05:49.362    Key block of 4,096 bytes has 8 512-byte sectors.")
    print("    14:05:49.362    Timeline:")
    print("    14:05:49.363    Wed Dec 18 2024 13:55:29.576 C5T Sector last written. (As found in the first corrupted sector, timestamp is taken just BEFORE the actual write).")
    print("    14:05:49.363    Wed Dec 18 2024 14:05:49.345 CST Key block first found to be corrupted during a workload requested read.")
    print("    14:05:49.363")
    print("    14:05:49.363    2 of 8 sectors are corrupted.")
    print("    14:05:49.363    All 2 corrupted sectors will be reported.")
    print("    14:05:49.363")
    print("    14:05:49.363         Data Validation error for fsd=fsd2; FSD lba: 0x28e55dcc00; Key block size: 4096； relative sector in data block: 0x06")
    print("    14:05:49.363         File name:/mnt/test1/client2/133/vdb.1_7.dir/vdb_f0054.file; file block lba:0x2550000; bad sector file lba: 0x255dcc00")
    print("    14:05:49.363         ===> Logical byte address miscompare. Expecting 0x28e55dcc00, receiving 0x20687dcc00")
    print("    14:05:49.363         Timestamp found in sector: Wed Dec 18 2024 13：55：29.576 CST")
    print("    14:05:49.363 0x000*  00000028 e55dcc00 ........ ........   00000020 687dcc00 00000193 d855eaa8")
    print("    14:05:49.363 0x010   02..0000 32647366 20202020 00000000   02530000 32647366 20202020 001a6dfc")
    print("    14:05:49.363         There are no mismatches in bytes 32-511")
    

def help_offset():
    print("\n查看vdbench输出数据不一致的日志，示例信息如下：\n")
    print_vdbench3()
    print("输出的内容中file lba: 0x00014c00表示offset为0x00014c00\n")
    print_vdbench6()
    print("输出的内容中bad sector file lba: 0x255dcc00表示offset为0x255dcc00\n")
    

def help_inode():
    print("\n查看vdbench输出数据不一致的日志，示例信息如下：\n")
    print_vdbench3()
    print("输出的内容中File name: /mnt/hwl_nfs_1/client1/vdb.1_1.dir/vdb.2_1.dir/vdb.3_1.dir/vdb_f0013.file表示数据不一致文件的绝对路径\n")
    print_vdbench6()
    print("输出的内容中File name:/mnt/test1/client2/133/vdb.1_7.dir/vdb_f0054.file表示数据不一致文件的绝对路径\n")
    print("用stat命令查看数据不一致文件的信息:")
    print("    stat /mnt/test1/client2/133/vdb.1_7.dir/vdb_f0054.file")
    print("      File: /mnt/test1/client2/133/vdb.1_7.dir/vdb_f0054.file")
    print("      Size: 0               Blocks: 0          IO Block: 4096   regular empty file")
    print("    Device: 253,7   Inode: 19922951    Links: 1")
    print("    Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)")
    print("    Access: 2025-05-06 13:41:19.511358194 +0800")
    print("    Modify: 2025-05-06 13:41:19.511358194 +0800")
    print("    Change: 2025-05-06 13:41:19.511358194 +0800")
    print("     Birth: 2025-05-06 13:41:19.511358194 +0800")
    print("输出的内容中Inode: 19922951表示inode为19922951\n")

def help_file():
    print("\n可以输入所有相关的udc日志和hos日志，程序默认先过滤所有udc日志，然后再过滤所有hos日志，示例如下:")
    print("    python iolkup.py 0 0x61100003b280 /var/log/storage/backup/udc/udc.log.uds.node180.log-2025050* /var/log/storage/backup/hos/*\n")

def is_hexadecimal_number(s):
    """判断字符串是否为16进制数字"""
    try:
        int(s, 16)
        return True
    except ValueError:
        return False

def is_file(filepath):
    """判断是否为文件"""
    return os.path.isfile(filepath)

def parse_udc_offset_and_length(log_line):
    """提取日志行中的偏移量和长度"""
    match = re.search(r'(\d+)~(\d+)', log_line)
    if match:
        offset = int(match.group(1))
        length = int(match.group(2))
        return offset, length
    return None, None

def udc_filter_logs(target_number, compiled_filters, log_files):
    """通过过滤规则和偏移条件过滤日志文件"""
    for log_file in log_files:
        # 输出文件的绝对路径
        absolute_path = os.path.abspath(log_file)
        print(f"Processing file: {absolute_path}")

        try:
            open_func = gzip.open if log_file.endswith('.gz') else open
            with open_func(log_file, 'rt', encoding='utf-8') as file:
                for line in file:
                    # 检查是否同时满足所有过滤规则
                    if all(pattern.search(line) for pattern in compiled_filters):
                        offset, length = parse_udc_offset_and_length(line)
                        if offset is not None and length is not None:
                            if offset <= target_number < (offset + length):
                                print(line.strip())

        except FileNotFoundError:
            print(f"File not found: {log_file}")
        except Exception as e:
            print(f"An error occurred while processing {log_file}: {e}")

def parse_hos_offset_and_length(log_line):
    """提取日志行中的偏移量和长度"""
    off_match = re.search(r'off:(\d+)', log_line)
    len_match = re.search(r'len:(\d+)', log_line)
    offset = 0
    length = 0
    if off_match:
        offset = int(off_match.group(1))
    if len_match:
        length = int(len_match.group(1))

    return offset, length

def hos_filter_logs(target_number, compiled_filters, log_files):
    """通过过滤规则和偏移条件过滤日志文件"""
    target_number = target_number % 4194304
    for log_file in log_files:
        # 输出文件的绝对路径
        absolute_path = os.path.abspath(log_file)
        print(f"Processing file: {absolute_path}")
        
        try:
            open_func = gzip.open if log_file.endswith('.gz') else open
            with open_func(log_file, 'rt', encoding='utf-8') as file:
                for line in file:
                    # 检查是否同时满足所有过滤规则
                    if all(pattern.search(line) for pattern in compiled_filters):
                        offset, length = parse_hos_offset_and_length(line)
                        if offset is not None and length is not None:
                            if offset <= target_number < (offset + length):
                                print(line.strip())

        except FileNotFoundError:
            print(f"File not found: {log_file}")
        except Exception as e:
            print(f"An error occurred while processing {log_file}: {e}")

def main():
    if len(sys.argv) < 3:
        print_help()
        sys.exit(1)
        
    if sys.argv[1] == "help":
        if sys.argv[2] == "inode":
            help_inode()
        elif sys.argv[2] == "offset":
            help_offset()
        elif sys.argv[2] == "file":
            help_file()
        else:
            print("未知参数{}".format(sys.argv[2]))
            sys.exit(1)
        sys.exit(1)
        
    target_number = 0
    if sys.argv[1].isdigit():
        target_number = int(sys.argv[1])
    elif is_hexadecimal_number(sys.argv[1]):
        target_number = int(sys.argv[1], 16)
    else:
        print("第一个参数为inode，请正确输入")
        sys.exit(1)

    args = sys.argv[2:]
    udc_filters = []
    udc_log_files = []
    hos_filters = []
    hos_log_files = []

    for arg in args:
        if is_file(arg):
            if "hos" in arg:
                hos_log_files.append(arg)
            else:
                udc_log_files.append(arg)
        else:
            if arg.isdigit():
                udc_filters.append(str(hex(int(arg))[2:]))
                hos_filters.append(arg + "." + str(target_number // 4194304))
            elif is_hexadecimal_number(arg):
                udc_filters.append(str(hex(int(arg, 16))[2:]))
                hos_filters.append(str(int(arg, 16)) + "." + str(target_number // 4194304))
            else:
                print("err arg:{}".format(arg))
                sys.exit(1)

    if not udc_log_files and not hos_log_files:
        print("输入的文件有误")
        sys.exit(1)

    print("offset:{} inode:{} obj:{}".format(target_number, udc_filters[0], hos_filters[0]))

    udc_filters.append("udc_write_split|udc_read_split")
    hos_filters.append("HOS_OPC_OBJ_WRITE|HOS_OPC_OBJ_READ")

    udc_compiled_filters = [re.compile(filter_) for filter_ in udc_filters]
    udc_filter_logs(target_number, udc_compiled_filters, udc_log_files)
    
    hos_compiled_filters = [re.compile(filter_) for filter_ in hos_filters]
    hos_filter_logs(target_number, hos_compiled_filters, hos_log_files)

if __name__ == "__main__":
    main()
