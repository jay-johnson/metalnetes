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

namespace="ae"
if [[ "${1}" != "" ]]; then
    namespace="${1}"
fi
key_name=pvc-ceph-client-key

anmt "------------------------------------"
anmt "copying ceph secret from ceph namespace to ${namespace}"

key_exists_in_ceph=$(kubectl get secret ${key_name} --namespace=ceph | wc -l)

if [[ "${key_exists_in_ceph}" == "0" ]]; then
    err "ERROR failed to find ceph secret in ceph namespace for credentials to use persistent volumes using c
ommand:"
    err "kubectl get secret ${key_name} --namespace=ceph"
    exit 1
fi

kubectl \
    get secret \
    ${key_name} --namespace=ceph \
    --export -o yaml | kubectl apply \
    --namespace=${namespace} -f -

key_exists_in_ae=$(kubectl get secret ${key_name} --namespace=${namespace} | wc -l)

if [[ "${key_exists_in_ae}" == "0" ]]; then
    err "ERROR failed to find ceph secret in ae namespace for credentials to use persistent volumes using command:"
    err "kubectl get secret ${key_name} --namespace=${namespace}"
    exit 1
fi

exit 0
