#!/bin/bash
set -e

SERVICE_NAME=${SERVICE_NAME}
USERNAME=${USERNAME:-user}
PASSWORD=${PASSWORD:-pass}
VOLUME=${VOLUME:-/data}

echo "${PASSWORD}" >/etc/rsyncd.pass
chmod 0600 /etc/rsyncd.pass
monitor() {
    target_syncds="$(getent hosts tasks.${SERVICE_NAME} | awk '{print $1}' | tr '\n' ',')"
    if [[ -z "${target_syncds}" ]]; then
        target_syncds="${SERVICE_NAME}"
    fi
    l_target_syncds=(${target_syncds//,/ })
    for target_syncd in ${l_target_syncds[@]}; do
        /usr/bin/inotifywait -mrq --format '%w%f' -e create,close_write,delete $1 | while read line; do
            if [ -f $line ]; then
                rsync -avz $line --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            else
                cd $1 &&
                    rsync -avz ./ --delete ${USERNAME}@${target_syncd}::volume --password-file=/etc/rsyncd.pass
            fi
        done
    done
}
monitor $VOLUME
