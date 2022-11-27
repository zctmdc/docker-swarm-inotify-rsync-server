#!/bin/bash
set -e

SERVICE_NAME=${SERVICE_NAME}
USERNAME=${USERNAME:-user}
PASSWORD=${PASSWORD:-pass}
VOLUME=${VOLUME:-/data}

echo "${PASSWORD}" >/etc/rsyncd.pass
chmod 0600 /etc/rsyncd.pass

rsync_file() {
    target_syncds="$(getent hosts tasks.${SERVICE_NAME} | awk '{print $1}' | tr '\n' ',')"
    if [[ -z "${target_syncds}" ]]; then
        target_syncds="${SERVICE_NAME}"
    fi
    l_target_syncds=(${target_syncds//,/ })
    for target_syncd in ${l_target_syncds[@]}; do
        if [ -f $1 ]; then
            rsync -avz $1 --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
        else
            cd $1 &&
                rsync -avz ${fisttime:+ -r} ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
        fi
    done
    fisttime=''
}
monitor() {
    echo "monitoring $1"
    /usr/bin/inotifywait -mrq --format '%w%f' -e create,close_write,delete $1 | while read line; do
        rsync_file $1
    done
}
fisttime=true
rsync_file $VOLUME
monitor $VOLUME
