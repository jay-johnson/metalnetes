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
anmt "deploying ${env_name} vms=${vms} with virsh with fqdns=${nodes} no_sleep=${no_sleep} KUBECONFIG=${KUBECONFIG}"

virsh list >> /dev/null 2>&1
virsh_ready=$?
cur_date=$(date)
while [[ "${virsh_ready}" != "0" ]]; do
    inf "${cur_date} - sleeping before starting vms"
    sleep 10
    virsh list >> /dev/null 2>&1
    virsh_ready=$?
    cur_date=$(date)
done

anmt "starting vms: ${vms}"

for vm in $vms; do
    running_test=$(virsh list | grep ${vm} | wc -l)
    if [[ -e /data/kvm/disks/${vm}.xml ]]; then
        if [[ "${running_test}" == "0" ]]; then
            anmt "importing ${vm}"
            virsh define /data/kvm/disks/${vm}.xml 2>&1
        fi
    fi
    running_test=$(virsh list | grep ${vm} | grep running | wc -l)
    if [[ "${running_test}" == "0" ]]; then
        anmt "setting autostart for vm with: virsh autostart ${vm}"
        virsh autostart ${vm}
        anmt "starting vm: virsh start ${vm}"
        virsh start ${vm}
    else
        anmt " - ${vm} already runnning"
    fi
done

inf "check login to vms: ${nodes}"
for fqdn in ${nodes}; do
    test_ssh=$(ssh ${login_user}@${fqdn} "date" 2>&1)
    not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
    cur_date=$(date)
    while [[ "${not_done}" != "0" ]]; do
        inf "${cur_date} - sleeping to let ${fqdn} start"
        sleep 10
        test_ssh=$(ssh ${login_user}@${fqdn} "date" 2>&1)
        not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
        cur_date=$(date)
    done
done

vm_list_for_grep=$(echo "${vms}" | sed -e 's/ /|/g')
anmt "checking vm status with: virsh list | grep -E \"${vm_list_for_grep}\""
virsh list | grep -E "${vm_list_for_grep}"

anmt "done deploying ${env_name} vms=${vms} with virsh with fqdns=${nodes} no_sleep=${no_sleep} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
