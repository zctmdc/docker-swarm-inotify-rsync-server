#!/bin/bash

set -e

SERVICE_NAMES=${SERVICE_NAMES}
USERNAME=${USERNAME:-user}
PASSWORD=${PASSWORD:-pass}
VOLUME=${VOLUME:-/data}

if [ ! -d "${VOLUME}" ] || [ ! -f "${VOLUME}" ]; then
    mkdir -p ${VOLUME}
fi
echo "${PASSWORD}" >/etc/rsyncd.pass
chmod 0600 /etc/rsyncd.pass

rsync_file() {
    l_service_names=(${SERVICE_NAMES//,/ })
    for service_name in ${l_service_names[@]}; do
        if [ -z "${service_name}" ]; then
            continue
        fi
        target_syncds="$(getent hosts tasks.${service_name} | awk '{print $1}' | tr '\n' ',')"
        if [ -z "${target_syncds}" ]; then
            target_syncds="$(getent hosts ${service_name} | awk '{print $1}' | tr '\n' ',')"
        fi
        if [ -z "${target_syncds}" ]; then
            target_syncds="${service_name}"
        fi
        l_target_syncds=(${target_syncds//,/ })
        for target_syncd in ${l_target_syncds[@]}; do
            if [ -z "${target_syncd}" ]; then
                continue
            fi
            echo "rsync file: ${target_syncd} -->  $1"
            if [ -f $1 ]; then
                rsync -az $1 --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            else
                cd $1 &&
                    rsync -avz ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            fi
        done
    done
}
monitor() {
    echo "monitoring $1"
    /usr/bin/inotifywait -mrq --format '%w%f' -e create,close_write,delete $1 | while read line; do
        rsync_file $line
    done
}
rsync_file $VOLUME
monitor $VOLUME
