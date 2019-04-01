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
nodes="${K8_NODES}"
login_user="${LOGIN_USER}"
vm_helper="${RUN_CMD_ON_VM}"

# defined in CLUSTER_CONFIG file to exit if kubernetes is not running
k8_ready=$(is_k8_ready)
if [[ "${k8_ready}" != "ONLINE" ]]; then
    err "${env_name} is not running on nodes: ${nodes}"
    exit 1
fi

# as of 1.14 there are now 2 taints to remove

anmt "$(date) - ${env_name}:$(hostname) - removing node-role.kubernetes.io/master taint"
kubectl taint nodes --all node-role.kubernetes.io/master-
anmt "$(date) - ${env_name}:$(hostname) - removing node.kubernetes.io/not-ready:NoSchedule taint"
kubectl taint nodes --all node.kubernetes.io/not-ready:NoSchedule-

good "done - ${env_name} checking scheduling:"
kubectl describe nodes | grep -i taints

exit 0
