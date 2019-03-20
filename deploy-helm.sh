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

anmt "----------------------------------------"
anmt "deploying helm locally for ${env_name} - these tools use helm to control kubernetes using auth creds: KUBECONFIG=${KUBECONFIG}"
anmt "details on helm: https://helm.sh/docs/"
inf ""

inf "checking if helm is running already"
helm_running=$(ps auwwx | grep helm | grep serve | wc -l)
if [[ "${helm_running}" == "0" ]]; then
    anmt "starting local helm server"
    helm serve &
    anmt " - sleeping"
    sleep 5
    helm_running=$(ps auwwx | grep helm | grep serve | wc -l)
    if [[ "${helm_running}" == "0" ]]; then
        err "failed starting local helm server"
        exit 1
    else
        good "helm is running"
    fi
else
    inf " - helm is already serving charts"
fi
inf ""

good "done - deploying helm locally for ${env_name} - helm will control kubernetes using auth creds: KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------"

exit 0
