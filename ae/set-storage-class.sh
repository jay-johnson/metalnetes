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

storage_class="rook-ceph-block"
if [[ "${1}" != "" ]]; then
    storage_class="${1}"
fi

default_storage_class=$(kubectl get storageclass | grep default | awk '{print $1}')
if [[ "${default_storage_class}" == "${storage_class}" ]]; then
    good "${env_name} - ${default_storage_class} already set as the default storage class"
    exit 0
fi

anmt "${env_name} - setting default storage class for ae"
if [[ "${default_storage_class}" != "" ]]; then
    anmt "${env_name} - changing storage class default from: ${default_storage_class} to: ${storage_class}"
    kubectl patch storageclass ${default_storage_class} -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >> /dev/null
fi
kubectl patch storageclass ${storage_class} -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

new_default_storage_class=$(kubectl get storageclass | grep default | awk '{print $1}')
if [[ "${new_default_storage_class}" == "${storage_class}" ]]; then
    good "${env_name} - ${storage_class} is the default StorageClass"
    echo ""
    kubectl get storageclass
    echo ""
    exit 0
else
    err "${env_name} - failed setting: ${storage_class} as the default StorageClass - choices are:"
    kubectl get storageclass
    exit 1
fi
