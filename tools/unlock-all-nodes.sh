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

# defined in CLUSTER_CONFIG file to exit if kubernetes is not running
k8_ready=$(is_k8_ready)
if [[ "${k8_ready}" != "ONLINE" ]]; then
    err "${env_name} is not running on nodes: ${nodes}"
    exit 1
fi

for i in ${nodes}; do
    # anmt "- ${env_name}:${i} setting up schedulgin: ssh ${login_user}@${i} \"kubectl --ignore-not-found taint nodes --all node-role.kubernetes.io/master-\""
    ssh ${login_user}@${i} "kubectl taint nodes --all node-role.kubernetes.io/master-"
    # anmt "- ${env_name}:${i} checking scheduling with: kubectl describe nodes ${i} | grep -i taints"
    # node_taint=$(kubectl describe nodes ${i} | grep -i taints)
    # anmt "- ${env_name}:${i} scheduling: ${node_taint}"
done

good "done - ${env_name} checking scheduling:"
kubectl describe nodes | grep -i taints

exit 0
