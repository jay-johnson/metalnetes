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

nodes="${K8_NODES}"
labels="${K8_LABELS}"
env_name="${K8_ENV}"

anmt "-------------------------"
anmt "${env_name}:$(hostname) - applying multihost labels"
anmt "labels: ${labels}"
anmt "nodes:  ${nodes}"
anmt "KUBECONFIG: ${KUBECONFIG}"

num_nodes=$(kubectl get nodes -o wide | grep Ready | wc -l)
if [[ "${num_nodes}" == "-" ]]; then
    anmt "unable to detect kubernetes nodes with KUBECONFIG=${KUBECONFIG}"
    inf ""
    exit 1
fi

anmt "detected kubernetes nodes: ${num_nodes}"

for node in ${nodes}; do
    # anmt "getting lables for all cluster nodes"
    node_name=$(kubectl get nodes | grep ${node} | awk '{print $1}')
    for label in $labels; do
        label_name=$(echo ${label} | sed -e 's/=/ /g' | awk '{print $1}')
        label_value=$(echo ${label} | sed -e 's/=/ /g' | awk '{print $2}')
        kubectl label nodes ${node_name} ${label} --overwrite >> /dev/null 2>&1
    done
done
    
anmt "review labels with:"
anmt "kubectl get nodes --show-labels -o wide"

good "${env_name}:$(hostname) - applying multihost labels"
anmt "-------------------------"

exit 0
