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
export CLUSTER_CONFIG=${path_to_env}

# defined in the CLUSTER_CONFIG
start_logger

env_name="${K8_ENV}"
use_repo="${REPO_BASE_DIR}"
debug="${METAL_DEBUG}"
namespace="ae"
start_registry="${START_REGISTRY}"
registry_secret="${REGISTRY_SECRET}"

# Start the Stock Analysis Engine
# https://github.com/AlgoTraders/stock-analysis-engine
ae_helm_deploy_tool="${AE_HELM_DEPLOY_TOOL}"
ae_values="${AE_VALUES}"
ae_deploy_dir="${AE_DEPLOY_DIR}"

anmt "----------------------------------------"
anmt "deploying ae to ${env_name} with KUBECONFIG=${KUBECONFIG}"
inf ""

# defined in CLUSTER_CONFIG file to exit if kubernetes is not running
stop_if_not_ready

# this will start tiller if it is not running
tiller_ready=$(is_tiller_ready)
if [[ "${tiller_ready}" == "0" ]]; then
    err "${env_name} - tiller is not running please run: ./deploy-tiller.sh"
    exit 1
fi

if [[ "$(kubectl get ns --ignore-not-found ae | wc -l)" == "0" ]]; then
    inf "creating ${namespace} namespace"
    kubectl create namespace ${namespace} >> /dev/null 2>&1
fi

if [[ "${start_registry}" == "1" ]] && [[ -e ${registry_secret} ]]; then
    anmt "installing private docker registry secret to namespace: ${namespace}"
    kubectl -n ${namespace} apply -f ${registry_secret}
else
    if [[ "${registry_secret}" != "" ]]; then
        anmt "did not find docker registry secret ${registry_secret}"
    else
        anmt "no registry secret set"
    fi
fi

anmt "starting ae on ${env_name} with:"
anmt "${ae_helm_deploy_tool} ${ae_deploy_dir} ${KUBECONFIG}"
cd ${ae_deploy_dir}
${ae_helm_deploy_tool} ${ae_deploy_dir} ${KUBECONFIG}
if [[ "$?" != "0" ]]; then
    err "failed to run ae starter: ${ae_helm_deploy_tool} ${ae_deploy_dir} ${KUBECONFIG}"
    cd ${cur_dir}
    exit 1
fi

# if [[ -e ${use_repo}/k8/deploy-latest.sh ]]; then
#     anmt "deploying latest engine and datasets from s3 to k8 and local docker redis servers"
#     anmt "${use_repo}/k8/deploy-latest.sh"
#     ${use_repo}/k8/deploy-latest.sh
# else
#     err "failed to find deploy-latest.sh"
#     cd ${cur_dir}
#     exit 1
# fi
cd ${cur_dir}

good "done - deploying ae to ${env_name} with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------"

exit 0
