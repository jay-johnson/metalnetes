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

namespace="ae"
resource="logs"

anmt "------------------------------------"
anmt "getting ${resource} in ${namespace}: "
pod_name=$(kubectl get pod -n ${namespace} | grep weekly | grep -v Termin | head -1 | awk '{print $1}')
good "kubectl ${resource} -n ${namespace} ${pod_name}"

kubectl ${resource} -n ${namespace} ${pod_name}
