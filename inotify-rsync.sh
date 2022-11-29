#!/bin/bash

# set -e

export SERVICE_NAMES=${SERVICE_NAMES}
export USERNAME=${USERNAME:-user}
export PASSWORD=${PASSWORD:-pass}
export VOLUME=${VOLUME:-/data}

if [ ! -d "${VOLUME}" ] || [ ! -f "${VOLUME}" ]; then
    mkdir -p ${VOLUME}
fi
echo "${PASSWORD}" >/etc/rsyncd.pass
chmod 0600 /etc/rsyncd.pass

all_target_syncds=''
check_service() {
    touch /tmp/all_target_syncds.txt
    touch /tmp/tmp_target_syncds.txt
    while true; do
        echo "check_service: checking"
        : >/tmp/tmp_target_syncds.txt
        l_service_names=(${SERVICE_NAMES//,/ })
        for service_name in ${l_service_names[@]}; do
            if [ -z "${service_name}" ]; then
                continue
            fi
            target_syncds=''
            target_syncds="$(getent hosts tasks.${service_name} | awk '{print $1}' | tr '\n' ',')"
            if [ -z "${target_syncds}" ]; then
                target_syncds="$(getent hosts ${service_name} | awk '{print $1}' | tr '\n' ',')"
            fi
            if [ -z "${target_syncds}" ]; then
                target_syncds="${service_name}"
            fi
            if [ "${target_syncds: -1}" = "," ]; then
                target_syncds="${target_syncds%?}"
            fi
            echo "${target_syncds}"
            echo "${target_syncds}" >>/tmp/tmp_target_syncds.txt
        done
        cp -f /tmp/tmp_target_syncds.txt /tmp/all_target_syncds.txt
        rsync_file $VOLUME
        sleep 30
    done
}
rsync_file() {
    if [ "${VERBOSE^^}" = "TRUE" ]; then
        use_verbose="true"
    fi
    if [ ! -s /tmp/all_target_syncds.txt ]; then
        # echo "rsync_file: No target syncds"
        return
    fi
    if [ ! -e "$1" ]; then
        # echo "rsync_file: No such file or directory: $1"
        return
    fi
    if [ -n "$(fuser $1)" ]; then
        echo "rsync_file: in use: $1"
        return
    fi
    # 1. 定义相关变量
    local concurrent=64                # 定义并发数, 在shell中叫 threadNum 不太合适, 因为是fork的子进程.
    local pfile="/tmp/rsync_file.fifo" # 定义管道文件路径
    local pfileFD="$RANDOM"            # 若本函数需多次调用时, 测试：可使用shell内置random函数, 范围:[0-32767)，不建议在生成使用，生成环境建议使用seq序列，因为当CPU过高时可能导致系统随机源不足产生重复随机数，这会导致一系列问题
    # 2. 创建Linux管道文件(写读数据会先进先出的队列, 类似java中Queue).
    [ ! -p "$pfile" ] && mkfifo $pfile
    eval "exec $pfileFD<>$pfile" # 创建文件句柄(fd), 除系统内置的0/1/2外的数字作为fd的标识即可, > 和 < 分别代表写读.
    rm -f $pfile                 # 创建完fd后可删除管道文件

    # 3. 初始化并发数, 即添加并发相同数量的换行符到FD, 用于后续读取换行符来控制并发数. (echo 默认标准输出换行符)
    eval "for ((i=0;i<${concurrent};i++)); do echo ; done >&${pfileFD}"
    # 4. 异步提交任务
    while read target_syncd; do
        eval "read -u${pfileFD}" # 每次读一个, 读完一个就少一个(fifo队列)
        {
            if [ -z "${target_syncd}" ]; then
                continue
            fi
            echo "rsync file: ${target_syncd} --  $1"
            if [ -f $1 ]; then
                rsync -az $1 --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            elif [ -d $1 ]; then
                cd $1 &&
                    rsync -az ${use_verbose:+ -v} ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            else
                cd $VOLUME &&
                    rsync -az ${use_verbose:+ -v} ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            fi
        } &
    done <<<"$(cat /tmp/all_target_syncds.txt)"
    wait
    eval "exec ${pfileFD}>&-" # 关闭fd(管道文件)
    return 0
}
monitor() {
    echo "monitoring $1"
    /usr/bin/inotifywait -mrq --format '%w%f' -e "close_write,modify,delete,create,attrib,move" $1 | while read line; do
        rsync_file $line
    done
}
check_service &
sleep 5
while true; do
    monitor $VOLUME
    sleep 5
done
