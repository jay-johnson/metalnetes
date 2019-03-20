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
charts="${AE_CHARTS}"

anmt "----------------------------------------------"
warn "deleting ${env_name} ae stack with KUBECONFIG=${KUBECONFIG}"
inf ""

for c in ${charts}; do
    anmt "deleting ${c} on ${env_name} with: helm del --purge ${c}"
    helm del --purge ${c}
done

good "done - deleting ${env_name} ae stack with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
