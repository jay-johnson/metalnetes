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

env_name="${K8_ENV}"
remote_tool_vm_prepare="${REMOTE_TOOL_VM_PREPARE}"

test_user=$(whoami)
if [[ "${test_user}" != "root" ]]; then
    err "please run as root"
    exit 1
fi

anmt "---------------------------------------------"
amnt "${env_name}:$(hostname) - resetting local kubernetes systems with: ${remote_tool_vm_prepare}"

anmt "${env_name}:$(hostname) - running: kubeadm reset -f"
kubeadm reset -f

${remote_tool_vm_prepare}
if [[ "$?" != "0" ]]; then
    err "${env_name}:$(hostname) - failed running remote vm prepare: ${remote_tool_vm_prepare}"
    exit 1
fi

good "done - ${env_name}:$(hostname) - resetting local kubernetes systems with: kubeadm reset -f and ${remote_tool_vm_prepare}"
anmt "---------------------------------------------"

exit 0
