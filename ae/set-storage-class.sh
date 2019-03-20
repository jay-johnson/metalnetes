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
anmt "setting default storage class for ae stack from:"
anmt "${default_storage_class} to: ${storage_class}"
kubectl patch storageclass ${default_storage_class} -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >> /dev/null
kubectl patch storageclass ${storage_class} -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

new_default_storage_class=$(kubectl get storageclass | grep default | awk '{print $1}')
if [[ "${new_default_storage_class}" == "${storage_class}" ]]; then
    good "${storage_class} is the default StorageClass"
    echo ""
    kubectl get storageclass
    echo ""
    exit 0
else
    err "Failed setting: ${storage_class} as the default StorageClass - choices are:"
    kubectl get storageclass
    exit 1
fi
