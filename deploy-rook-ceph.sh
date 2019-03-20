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
use_repo="${USE_REPO}"
debug="${METAL_DEBUG}"

storage_namespace="${STORAGE_NAMESPACE}"
storage_type="${STORAGE_TYPE}"
storage_values="${STORAGE_VALUES}"
storage_operator="${STORAGE_OPERATOR}"

anmt "----------------------------------------"
anmt "deploying rook-ceph to ${env_name} using helm with KUBECONFIG=${KUBECONFIG}"
anmt "details on the rook-ceph operator: https://rook.io/docs/rook/master/helm-operator.html"
inf ""
good "namespace=${storage_namespace}"
good "storage_values=${storage_values}"
good "storage_type=${storage_type}"
good "storage_operator=${storage_operator}"
inf ""

if [[ "${storage_type}" == "helm-rook-ceph" ]]; then
    anmt "helm repo add rook-stable https://charts.rook.io/stable"
    helm repo add rook-stable https://charts.rook.io/stable

    anmt "helm repo update"
    helm repo update

    anmt "helm repo list"
    helm repo list

    anmt "helm install --namespace ${storage_namespace} rook-stable/rook-ceph -f ${storage_values}"
    helm install --namespace ${storage_namespace} rook-stable/rook-ceph -f ${storage_values}
else
    anmt "running rook-ceph operator=${storage_operator} storage_type=${storage_type}"
    ${storage_operator}
    if [[ "$?" != "0" ]]; then
        err "failed to start rook-ceph operator with: ${storage_operator} and KUBECONFIG=${KUBECONFIG}"
        exit 1
    fi
fi

anmt "waiting for rook ceph to start up"
wait_for_rook_ceph

good "done - deploying rook-ceph to ${env_name} storage_type=${storage_type} using helm with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------"

exit 0
