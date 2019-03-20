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
namespace="default"

anmt "${env_name} - kubectl describe pods -n default --ignore-not-found nginx"
pod_name=$(kubectl get po -n ${namespace} | grep nginx | grep Running | awk '{print $1}' | head -1)
if [[ "${pod_name}" == "" ]]; then
    err "${env_name} does not have the nginx ingress running in the ${namespace} namespace"
    exit 1
else
    kubectl describe pods -n ${namespace} ${pod_name}
fi

exit 0
