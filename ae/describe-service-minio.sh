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
resource="service"

anmt "---------------------------------------------------------"
anmt "Describing minio ${resource} namespace ${namespace}"
inf ""
pod_name=$(kubectl get ${resource} -n ${namespace} | grep minio | grep -v Termin | head -1 | awk '{print $1}')
good "kubectl describe ${resource} -n ${namespace} ${pod_name}"
inf ""
kubectl describe ${resource} -n ${namespace} ${pod_name}
