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
use_repo="${USE_REPO}"
debug="${METAL_DEBUG}"

tool_nginx_starter="$(dirname ${path_to_env})/nginx/run.sh"

anmt "----------------------------------------"
anmt "deploying nginx to ${env_name} with ${tool_nginx_starter} and KUBECONFIG=${KUBECONFIG}"
inf ""

${tool_nginx_starter}
if [[ "$?" != "0" ]]; then
    err "failed to start nginx with ${tool_nginx_starter} and KUBECONFIG=${KUBECONFIG}"
    exit 1
fi

good "done - deploying nginx to ${env_name} with ${tool_nginx_starter} and KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------"

exit 0
