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

src_namespace="default"
src_secret="ae.docker.creds"
dst_namespace="ae"
dst_secret="ae.docker.creds"

anmt "------------------------------------"
anmt "copying ${src_secret} secret from ${src_namespace} namespace to ${dst_namespace}"

key_exists_in_default=$(kubectl get secret ${src_secret} --namespace=${src_namespace} | wc -l)

if [[ "${key_exists_in_default}" == "0" ]]; then
    err "ERROR failed to find ${src_namespace} secret in ${src_namespace} namespace for credentials to use persistent volumes using c
ommand:"
    err "kubectl get secret ${src_secret} --namespace=${src_namespace}"
    exit 1
fi

kubectl \
    get secret \
    ${src_secret} --namespace=${src_namespace} \
    --export -o yaml | kubectl apply \
    --namespace=${dst_namespace} -f -

key_exists_in_ae=$(kubectl get secret ${dst_secret} --namespace=${dst_namespace} | wc -l)

if [[ "${key_exists_in_ae}" == "0" ]]; then
    err "ERROR failed to find ${dst_secret} secret in ${dst_namespace} namespace for credentials to use persistent volumes using command:"
    err "kubectl get secret ${dst_secret} --namespace=${dst_namespace}"
    exit 1
fi

exit 0
