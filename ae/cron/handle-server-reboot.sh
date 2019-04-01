#!/bin/bash

# please set this in the cron job line:
#
# @reboot export METAL_BASE=/opt/ae/k8/dev && ${METAL_BASE}/ae/cron/handle-server-reboot.sh >> /tmp/ae-dev.log 2>&1
# or put into another script that calls it without the @reboot directive
# log=/tmp/metal-dev.log
# echo "$(date) - cron job - start - deploying metal dev" >> ${log}
# export METAL_BASE=/opt/ae/k8/dev && ${METAL_BASE}/ae/cron/handle-server-reboot.sh >> ${log} 2>&1
# echo "$(date) - cron job - done - deploying metal dev" >> ${log}

export CLUSTER_CONFIG=${METAL_BASE}/k8.env
cur_dir=$(pwd)

# change to the metal base dir
cd ${METAL_BASE}

path_to_env="${cur_dir}/k8.env"
if [[ "${CLUSTER_CONFIG}" != "" ]]; then
    path_to_env="${CLUSTER_CONFIG}"
fi
if [[ ! -e ${path_to_env} ]]; then
    if [[ -e ${cur_dir}/../k8.env ]]; then
        cur_dir=".."
        path_to_env="${cur_dir}/k8.env"
    else
        echo "failed to find env file: ${path_to_env} with CLUSTER_CONFIG=${CLUSTER_CONFIG}"
        exit 1
    fi
fi
source ${path_to_env}

env_name="${K8_ENV}"
cluster_starter="${K8_START}"

export START_AE="1"
ae_starter="${AE_STARTER}"
ae_cron_starter="${AE_CRON_STARTER}"

anmt "---------------------------------------------"
anmt "$(date) - ${env_name}:$(hostname) - starting reboot with METAL_BASE=${METAL_BASE} CLUSTER_CONFIG=${CLUSTER_CONFIG} KUBECONFIG=${KUBECONFIG}"
pwd

anmt "$(date) - ${env_name}:$(hostname) - starting cluster: ${cluster_starter}"
${cluster_starter}
if [[ "$?" != "0" ]]; then
    err "$(date) - ${env_name}:$(hostname) - failed starting cluster: ${cluster_starter}"
    exit 1
fi

if [[ "${START_AE}" == "1" ]]; then
    warn "---------------------------------------------"
    anmt "$(date) - ${env_name}:$(hostname) - starting ae: ${ae_starter}"
    ${ae_starter}
    if [[ "$?" != "0" ]]; then
        err "$(date) - ${env_name}:$(hostname) - failed starting ae: ${ae_starter}"
        exit 1
    else
        good "$(date) - ${env_name}:$(hostname) - started ae"
    fi

    anmt "$(date) - ${env_name}:$(hostname) - running ae restore cron job: ${ae_cron_starter} restore"
    ${ae_cron_starter} restore
    if [[ "$?" != "0" ]]; then
        err "$(date) - ${env_name}:$(hostname) - failed running ae restore cron job: ${ae_cron_starter} restore"
        exit 1
    else
        good "$(date) - ${env_name}:$(hostname) - done ae restore cron job"
    fi
    anmt "$(date) - ${env_name}:$(hostname) - done deploying ae"
    warn "---------------------------------------------"
fi

good "$(date) - ${env_name}:$(hostname) - done starting cluster"
anmt "---------------------------------------------"

exit 0
