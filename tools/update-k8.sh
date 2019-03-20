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

anmt "-------------------------"
anmt "${env_name}:$(hostname) - installing kubernetes updates:"
inf "yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes"
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

good "done - ${env_name}:$(hostname) - installing kubernetes updates"
anmt "-------------------------"
