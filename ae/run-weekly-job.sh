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
values="./ae-weekly/values.yaml"
recreate="0"

if [[ "${1}" != "" ]]; then
    if [[ "${1}" == "-r" ]]; then
        recreate="1"
    else
        if [[ ! -e ${1} ]]; then
            err "Failed to find weekly job values file: ${1}"
            exit 1
        fi
        values=${1}
    fi
fi

if [[ "${2}" != "" ]]; then
    if [[ "${2}" == "-r" ]]; then
        recreate="1"
    else
        if [[ ! -e ${2} ]]; then
            err "Failed to find weekly job values file: ${2}"
            exit 1
        fi
        values=${2}
    fi
fi

if [[ "${recreate}" == "1" ]]; then
    anmt "deleting previous ae weekly job"
    helm delete --purge ae-weekly
    pod_name="weekly"
    not_done=$(/usr/bin/kubectl get po -n ${namespace} | grep ${pod_name} | wc -l)
    while [[ "${not_done}" != "0" ]]; do
        date -u +"%Y-%m-%d %H:%M:%S"
        echo "sleeping while waiting for ${pod_name} to stop"
        sleep 5
        /usr/bin/kubectl get po -n ${namespace} | grep ${pod_name}
        not_done=$(/usr/bin/kubectl get po -n ${namespace} | grep ${pod_name} | wc -l)
    done
fi

# install ae first to get the secrets for minio and redis
anmt "installing ae weekly job"
good "helm install --name=ae-weekly ./ae-weekly --namespace=${namespace} -f ${values}"
helm install \
    --name=ae-weekly \
    ./ae-weekly \
    --namespace=${namespace} \
    -f ${values}

anmt "checking running charts:"
helm ls

anmt "getting pods in ae namespace:"
kubectl get pods -n ae
