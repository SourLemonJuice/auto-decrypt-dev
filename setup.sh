#!/bin/env bash
set -e

# Config
_Device_Path="/dev/disk/by-uuid/<uuid>"
_Key_File_Path="./dm-key"
_DM_Name="dm-crypt-name"

# errored_exit v2
# 如果上一个命令执行错误则以同样的报错码退出
llib_errored_exit(){
    _error_code=$?
    if [ ! $_error_code == 0 ];then
        echo "此前执行的命令执行错误 错误码:$_error_code"
        exit $_error_code
    fi
}

# prompts_need_perm v2
# 检测并提示提示用户需要别的权限
# 依赖: errored_exit
# (应用/用户)权限 == Permissions == perm
# 参数:
# $1 == Switch( * || 1 )(default on == 1)
# $2 == User( username || 1000 )(default root == 0 )
llib_prompts_need_perm(){
    _Switch=1
    [[ ! -z $1 ]] && _Switch=$1

    _User=0
    [[ ! -z $2 ]] && _User=$2

    _User_id=$(id -u ${_User})
    llib_errored_exit

    # 检测权限
    if [[ $_Switch -eq 1 ]];then

        if [[ ! $(id -u) -eq $_User_id ]];then
            echo "需要 uid:${_User_id} 的权限执行"
            exit 1
        fi
    fi
}

# 检测设备是否为符号链接
if [[ ! -h "$_Device_Path" ]]; then
    echo "错误：设备目标不存在，或是高耦合的设备描述名（e.g. /dev/sda）"
    exit 1
fi

# 检测密钥是否存在
if [[ ! -f "$_Key_File_Path" ]]; then
    echo "错误：密钥不存在"
    exit 1
fi

llib_prompts_need_perm "1" "root"

case "$1" in
close)
    if [[ ! -e "/dev/mapper/${_DM_Name}" ]]; then
        echo "错误：映射设备不存在"
        exit 1
    fi

    umount "/dev/mapper/${_DM_Name}" || exit 1
    cryptsetup close "$_DM_Name" || exit 1
    exit 0
    ;;
eject)
    eject "$_Device_Path" || exit 1
    ;;
decrypt)
    if [[ -e "/dev/mapper/${_DM_Name}" ]]; then
        echo "错误：映射设备已存在，请手动确认"
        exit 1
    fi

    echo "解密设备..."
    cryptsetup open --key-file "$_Key_File_Path" "$_Device_Path" "$_DM_Name" || exit 1

    echo "挂载映射设备..."
    # 检测挂载目录是否创建并修复
    # [[ -d "/mnt/crypt/${_DM_Name}" ]] || mkdir -p "/mnt/crypt/${_DM_Name}"
    mount --mkdir "/dev/mapper/${_DM_Name}" "/mnt/crypt/${_DM_Name}" || exit 1

    exit 0
    ;;
help | *)
    echo "help(default) | close | eject | decrypt"
    ;;
esac
