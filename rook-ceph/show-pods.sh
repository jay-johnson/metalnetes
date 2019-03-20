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
use_path="${cur_dir}/rook-ceph"
secrets_path="${use_path}/secrets"
cert_env="dev"

anmt "----------------------------------------------"
anmt "showing rook-ceph ${env_name} pods with KUBECONFIG=${KUBECONFIG}"
inf ""

good "rook-ceph pods:"
inf "kubectl get -n rook-ceph po"
kubectl get -n rook-ceph po
inf ""

good "rook-ceph-system pods:"
inf "kubectl get -n rook-ceph-system po"
kubectl get -n rook-ceph-system po
inf ""

anmt "done - showing rook-ceph ${env_name} pods with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
