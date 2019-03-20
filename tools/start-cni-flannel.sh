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

anmt "---------------------------------------------"
warn "${env_name}:$(hostname) - starting CNI Flannel with KUBECONFIG=${KUBECONFIG}"

url="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
anmt "${env_name}:$(hostname) - kubectl -n kube-system apply -f ${url}"
kubectl -n kube-system apply -f ${url}
if [[ "$?" != "0" ]]; then
    err "failed deploying flannel on: ${env_name}:$(hostname) with: "
    err "kubectl -n kube-system apply -f ${url}"
    exit 1
fi
inf ""

good "done - ${env_name}:$(hostname) - starting CNI Flannel with KUBECONFIG=${KUBECONFIG}"
anmt "---------------------------------------------"

exit 0
