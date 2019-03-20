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

name=""
key=""
cert=""

if [[ "${1}" != "" ]]; then
    name="${1}"
fi

if [[ -e "${2}" ]]; then
    key="${2}"
fi

if [[ -e "${3}" ]]; then
    cert="${3}"
fi

if [[ "${4}" != "" ]]; then
    namespace="${4}"
fi

if [[ "${name}" == "" ]]; then
    err "please set a secret name with usage: ./install-certs.sh secret_name key.pem cert.pem"
    exit 1
fi

if [[ "${key}" == "" ]]; then
    err "please set a key with usage: ./install-certs.sh secret_name key.pem cert.pem"
    exit 1
fi

if [[ "${cert}" == "" ]]; then
    err "please set a cert with usage: ./install-certs.sh secret_name key.pem cert.pem"
    exit 1
fi

anmt "------------------------------------"
anmt "creating tls secret: ${name}"
good "kubectl -n ${namespace} create secret tls ${name} --key ${key} --cert ${cert}"
kubectl -n ${namespace} create secret tls ${name} --key ${key} --cert ${cert}
