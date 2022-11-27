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
        sleep 30
    done
}
rsync_all() {
    touch /tmp/Synchronized.txt
    while true; do
        echo "rsync_all: checking"
        if [ ! -s /tmp/all_target_syncds.txt ]; then
            echo "rsync_file: No target syncds"
            return
        fi
        cat /tmp/all_target_syncds.txt | while read target_syncd; do
            if [ -z "${target_syncd}" ]; then
                # echo "rsync_all: target_syncd - blank"
                continue
            fi
            if [ -n "$(grep -e ^${target_syncd}$ /tmp/Synchronized.txt)" ]; then
                # echo "rsync_all: Synchronized - ${target_syncd}"
                continue
            fi
            echo "rsync all -- ${target_syncd}"
            rsync -avz $VOLUME --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            echo ${target_syncd} >>/tmp/Synchronized.txt
        done
        sleep 30
    done
}
rsync_file() {
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
    cat /tmp/all_target_syncds.txt | while read target_syncd; do
        if [ -z "${target_syncd}" ]; then
            continue
        fi
        echo "rsync file: ${target_syncd} -->  $1"
        if [ -f $1 ]; then
            rsync -az $1 --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
        elif [ -d $1 ]; then
            cd $1 &&
                rsync -avz ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
        else
            cd $VOLUME &&
                rsync -avz ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
        fi
    done
}
monitor() {
    echo "monitoring $1"
    /usr/bin/inotifywait -mrq --format '%w%f' -e "create,delete,close_write,attrib,move" $1 | while read line; do
        rsync_file $line
    done
}
check_service &
sleep 5
rsync_all &
monitor $VOLUME
