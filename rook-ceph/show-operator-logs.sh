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
namespace="rook-ceph-system"

pod_name=$(kubectl get -n ${namespace} po | grep rook-ceph-operator | head -1 | awk '{print $1}')
if [[ "${pod_name}" == "" ]]; then
    err "${namespace} operator is not running on ${env_name} - please run: deploy-rook-ceph.sh"
    exit 1
fi

anmt "----------------------------------------------"
anmt "getting ${env_name} ${namespace} operator logs for pod=${pod_name} KUBECONFIG=${KUBECONFIG}"
kubectl logs -n ${namespace} ${pod_name}
anmt "----------------------------------------------"

exit 0
