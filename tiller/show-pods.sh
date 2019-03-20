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
use_path="${cur_dir}/rook-ceph"
secrets_path="${use_path}/secrets"
cert_env="dev"

anmt "----------------------------------------------"
anmt "showing tiller pods on ${env_name} with KUBECONFIG=${KUBECONFIG}"
inf ""

good "tiller pod:"
inf "kubectl get -n kube-system po | grep tiller"
kubectl get -n kube-system po | grep tiller
inf ""

anmt "done - showing tiller pods on ${env_name} with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
