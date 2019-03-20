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

anmt "deleting secrets"
secrets=$(kubectl get secrets -n ${namespace} | grep "ae" | awk '{print $1}')
for s in ${secrets}; do
    anmt " - deleting secret ${s}"
    kubectl delete secret -n ${namespace} --ignore-not-found ${s}
done

exit 0
