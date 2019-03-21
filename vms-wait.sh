#!/bin/bash

cur_dir=$(pwd)
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

# defined in the CLUSTER_CONFIG
start_logger

initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
vms="${K8_VMS}"
env_name="${K8_ENV}"
login_user="${LOGIN_USER}"
debug="${METAL_DEBUG}"
no_sleep="0"

########################################

for i in "$@"
do
    contains_equal=$(echo ${i} | grep "=")
    if [[ "${i}" == "-d" ]]; then
        debug="1"
    elif [[ "${i}" == "-s" ]]; then
        no_sleep="1"
    else
        err "unsupported argument: ${i}"
        exit 1
    fi
done

anmt "----------------------------------------------"
anmt "waiting on ${env_name} vms: ${vms} to be ready for no_sleep=${no_sleep} KUBECONFIG=${KUBECONFIG}"

# there's probably a cleaner way to detect the vm's can start running k8...
if [[ "${no_sleep}" == "0" ]]; then
    cur_date=$(date)
    inf "${cur_date} - sleeping to let vms start 2 min left"
    sleep 60
    cur_date=$(date)
    inf "${cur_date} - sleeping to let vms start 1 min left"
    sleep 60
    cur_date=$(date)
    good "${cur_date} - done sleeping"
fi

vm_list_for_grep=$(echo "${vms}" | sed -e 's/ /|/g')
anmt "checking vm status with: virsh list | grep -E \"${vm_list_for_grep}\""
virsh list | grep -E "${vm_list_for_grep}"

good "done - waiting on ${env_name} vms: ${vms} to be ready for no_sleep=${no_sleep} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
