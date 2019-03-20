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
namespace="rook-ceph"

inf ""
anmt "----------------------------------------------"
anmt "getting ${env_name} rook-ceph status with toolbox with KUBECONFIG=${KUBECONFIG}"
pod_name=$(kubectl -n ${namespace} get po | grep rook-ceph-tools | awk '{print $1}')
if [[ "${pod_name}" == "" ]]; then
    err "rook-ceph-tools is not running"
    exit 1
else
    inf "kubectl -n ${namespace} exec -it ${pod_name} ceph status"
    kubectl -n ${namespace} exec -it ${pod_name} -- ceph status
fi

exit 0
