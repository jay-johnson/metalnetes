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
nodes="${K8_INITIAL_MASTER} ${K8_SECONDARY_MASTERS}"
num_k8_nodes_expected=$(echo "${nodes}" | sed -e 's/ /\n/g' | wc -l)
namespace="rook-ceph-system"

pod_name=$(kubectl get -n ${namespace} po | grep rook-ceph-operator | grep -v Running | head -1 | awk '{print $1}')
num_running_operators=$(kubectl get -n ${namespace} po | grep rook-ceph-operator | grep Running | wc -l)

anmt "----------------------------------------------"
anmt "describing ${env_name} ${namespace} operator pod=${pod_name} KUBECONFIG=${KUBECONFIG}"
if [[ "${pod_name}" == "" ]]; then
    kubectl describe po -n ${namespace} ${pod_name}
fi
inf ""
if [[ "${num_running_operators}" == "${num_k8_nodes_expected}" ]]; then
    good "done - ${env_name} - ${namespace} has all ${num_running_operators} of ${num_k8_nodes_expected} rook-ceph operators running"
else
    err "done - ${env_name} - ${namespace} not all rook-ceph operators are running ${num_running_operators} of ${num_k8_nodes_expected}"
    kubectl get -n ${namespace} po
    anmt "----------------------------------------------"
    exit 1
fi

anmt "----------------------------------------------"

exit 0
