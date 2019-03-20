#!/bin/bash

cur_dir=$(pwd)
path_to_env="${cur_dir}/k8.env"
if [[ "${CLUSTER_CONFIG}" != "" ]]; then
    path_to_env="${CLUSTER_CONFIG}"
fi
if [[ ! -e ${path_to_env} ]]; then
    echo "failed to find env file: ${path_to_env} with CLUSTER_CONFIG=${CLUSTER_CONFIG}"
    exit 1
fi
source ${path_to_env}

env_name="${K8_ENV}"
nodes="${K8_NODES}"
namespace="rook-ceph-system"

inf ""
anmt "-----------------------------------------"
good "getting the rook-ceph system pods on ${env_name} nodes=${nodes}:"
inf "kubectl -n ${namespace} get pod"
kubectl -n ${namespace} get pod
