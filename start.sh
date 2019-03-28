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

# export for additional bash scripts to use later
export CLUSTER_CONFIG=${path_to_env}

# defined in the CLUSTER_CONFIG
start_logger

# this assumes the current user has root ssh access to the following hosts:
initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
num_k8_nodes_expected=$(echo "${nodes}" | sed -e 's/ /\n/g' | wc -l)
vms="${K8_VMS}"
env_name="${K8_ENV}"
k8_ssh_key="${K8_SSH_KEY}"
k8_clean="${K8_CLEANER}"
k8_vm_start="${K8_VM_START}"
k8_vm_wait="${K8_VM_WAIT}"
k8_dns_server_1="${K8_DNS_SERVER_1}"
k8_domain="${K8_DOMAIN}"
login_user="${LOGIN_USER}"
deploy_ssh_key="${DEPLOY_SSH_KEY}"
tool_dns_etc_resolv="${TOOL_DNS_ETC_RESOLV}"
tool_unlock_nodes="${TOOL_UNLOCK_NODES}"
k8_config_dir="${K8_CONFIG_DIR}"
k8_tools_dir="${K8_TOOLS_DIR}"
debug="${METAL_DEBUG}"
no_sleep="0"
only_join="0"

########################################

start_clean="${START_CLEAN}"
start_registry="${START_REGISTRY}"
registry_starter="${REGISTRY_STARTER}"
registry_secret="${REGISTRY_SECRET}"
start_helm="${START_HELM}"
helm_starter="${HELM_STARTER}"
tiller_starter="${TILLER_STARTER}"

# storage layer
start_storage="${START_STORAGE}"
storage_type="${STORAGE_TYPE}"
storage_starter="${STORAGE_STARTER}"

# Start the Stock Analysis Engine
# https://github.com/AlgoTraders/stock-analysis-engine
# disable with: export START_AE=0
start_ae="${START_AE}"
ae_values="${AE_VALUES}"
ae_starter="${AE_STARTER}"

if [[ "${start_clean}" == "1" ]]; then
    start_registry=1
    only_join="0"
fi

for i in "$@"
do
    contains_equal=$(echo ${i} | grep "=")
    if [[ "${i}" == "-s" ]]; then
        no_sleep="1"
    elif [[ "${i}" == "-c" ]]; then
        start_clean="1"
        only_join="0"
    elif [[ "${i}" == "-a" ]]; then
        start_clean="1"
        start_ae="1"
        only_join="0"
    elif [[ "${i}" == "-j" ]]; then
        start_clean="0"
        start_ae="0"
        only_join="1"
    else
        err "unsupported argument: ${i}"
        exit 1
    fi
done

anmt "----------------------------------------------"
anmt "$(date) - starting ${env_name} kubernetes vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
date
anmt "Starting flags:"
anmt "clean=${start_clean}"
anmt "registry=${start_registry}"
anmt "helm=${start_helm}"
anmt "ae=${start_ae}"
anmt "storage=${storage_type} starter=${storage_starter}"
anmt "only_join=${only_join}"
anmt "current_dir=${cur_dir}"
anmt "vm_k8_config_dir=${k8_config_dir}"
anmt "vm_k8_tools_dir=${k8_tools_dir}"
anmt "-----------------------------"

anmt "$(date) - ${env_name}:$(hostname) - initializing cluster access with: metal"
metal

if [[ ! -e ${helm_starter} ]]; then
    err "please run ./boot.sh from the base directory of the repository"
    err "currently in: $(pwd)"
    exit 1
fi

inf ""
if [[ ! -e ${k8_config_dir} ]]; then
    anmt "creating local k8_config_dir: ${k8_config_dir}"
    mkdir -p -m 775 ${k8_config_dir}
    if [[ "$?" != "0" ]]; then
        err "failed to create k8_config_dir ${k8_config_dir} locally with:"
        err "mkdir -p -m 775 ${k8_config_dir}"
        err "please confirm your user has permissions to create the directory:"
        ls -lrt $(dirname ${k8_config_dir})
        exit 1
    fi
fi
if [[ ! -e ${k8_tools_dir} ]]; then
    mkdir -p -m 775 ${k8_tools_dir}
    anmt "creating local k8_tools_dir: ${k8_tools_dir}"
    if [[ "$?" != "0" ]]; then
        err "failed to create k8_tools_dir ${k8_tools_dir} locally with:"
        err "mkdir -p -m 775 ${k8_tools_dir}"
        err "please confirm your user has permissions to create the directory:"
        ls -lrt $(dirname ${k8_tools_dir})
        exit 1
    fi
fi

anmt "$(date) - starting ${env_name} vms: ${vms} with: ${k8_vm_start}"
${k8_vm_start}

if [[ "${start_registry}" == "1" ]]; then
    if [[ ! -e ${registry_starter} ]]; then
        err "$(date) - ${env_name} - failed to find private docker registry starter: ${registry_starter}"
        exit 1
    fi
    anmt "$(date) - ${env_name} - starting private docker registry with: ${registry_starter}"
    ${registry_starter}
    if [[ "$?" != "0" ]]; then
        err "$(date) - ${env_name} - failed to start private docker registry: ${registry_starter}"
        exit 1
    fi
fi

# helm runs outside kubernetes - install before starting the cluster
if [[ "${start_helm}" == "1" ]]; then
    anmt "$(date) - ${env_name} - starting helm: ${helm_starter}"
    ${helm_starter}
    if [[ "$?" != "0" ]]; then
        err "$(date) - ${env_name} - failed to start helm with: ${helm_starter}"
        exit 1
    fi
fi

anmt "$(date) - deploying kubernetes cluster"
date

if [[ "${no_sleep}" != "0" ]]; then
    anmt "$(date) - waiting on vms to start: ${k8_vm_wait} ${no_sleep}"
    ${k8_vm_wait} ${no_sleep} 
fi

anmt "$(date) - installing ${env_name} kubernetes cluster ${initial_master}:/etc/kubernetes/admin.conf to $(hostname):${KUBECONFIG} using ssh key: ${k8_ssh_key}"
scp -q -i ${k8_ssh_key} ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}
exit_code_getting_an_existing_cluster_admin_config=$?
need_to_clean="0"

if [[ "${exit_code_getting_an_existing_cluster_admin_config}" != "0" ]]; then
    err "cluster ${env_name} - did not successfully ssh into ${initial_master} as ${login_user} with command:"
    inf "scp -i ${k8_ssh_key} ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}"
    need_to_clean="1"
elif [[ ! -e ${KUBECONFIG} ]]; then
    err "$(date) - cluster ${env_name} - did not find a valid ${KUBECONFIG}"
    need_to_clean="1"
fi

anmt "$(date) - checking for ${env_name} cluster nodes: ${num_k8_nodes_expected}"
inf "kubectl get nodes -o wide | grep Ready | wc -l"
num_k8_nodes_found=$(kubectl get nodes -o wide | grep Ready | wc -l)
if [[ "${num_k8_nodes_found}" != "${num_k8_nodes_expected}" ]]; then
    err "$(date) - cluster ${env_name} - does not have the expected number of nodes=${num_k8_nodes_expected} found=${num_k8_nodes_found}"
    inf ""
    kubectl get nodes -o wide
    inf ""
    need_to_clean="1"
fi

anmt "$(date) - ${env_name} running /etc/resolv.conf installer: ${tool_dns_etc_resolv} DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
${tool_dns_etc_resolv}
if [[ "$?" != "0" ]]; then
    err "$(date) - failed to set /etc/resolv.conf on ${env_name} nodes=${nodes} with: ${tool_dns_etc_resolv}"
    exit 1
fi
    
if [[ "${need_to_clean}" == "1" ]] || [[ "${start_clean}" == "1" ]]; then
    if [[ "${need_to_clean}" == "1" ]]; then
        inf ""
        warn "--------------------------------------------------------"
        warn "detected ${env_name} cluster should be cleaned and reset"
        warn "--------------------------------------------------------"
        inf ""
    else
        inf ""
        inf "cleaning per start_clean flag=${start_clean}"
    fi
    anmt "$(date) - starting clean reset tool: ${k8_clean}"
    ${k8_clean}
    if [[ "$?" != "0" ]]; then
        err "$(date) - failed cleaning ${env_name} cluster with tool: ${k8_clean}"
        exit 1
    fi
    inf ""
else
    good "$(date) - found ${env_name} cluster has ${num_k8_nodes_found} nodes in a Ready state"
fi
inf ""

# defined in CLUSTER_CONFIG file to exit if kubernetes is not running
stop_if_not_ready

anmt "$(date) - scheduling ${env_name} on nodes: ${nodes} with: ${tool_unlock_nodes}"
${tool_unlock_nodes}
if [[ "$?" != "0" ]]; then
    err "$(date) - ${env_name} failed setting scheduling: ${tool_unlock_nodes}"
    exit 1
fi

anmt "$(date) - showing ${env_name} kubernetes nodes:"
kubectl get nodes -o wide

anmt "$(date) - getting pods"
kubectl get pods

anmt "$(date) - returning to ${cur_dir}"
cd ${cur_dir}

if [[ "${start_registry}" == "1" ]]; then
    anmt "$(date) - installing docker registry secret"
    kubectl create -f ${registry_secret} -n default
fi

# tiller deploys in the kubernetes cluster - so it start once the cluster is ready
if [[ "${start_helm}" == "1" ]]; then
    anmt "$(date) - starting tiller: ${tiller_starter}"
    ${tiller_starter}
    if [[ "$?" != "0" ]]; then
        err "failed to start tiller with: ${tiller_starter}"
        exit 1
    fi
fi

# storage deploys inside the kubernetes cluster - so it start once the cluster is ready
if [[ "${start_storage}" == "1" ]]; then
    anmt "$(date) - starting storage: ${storage_type} starter: ${storage_starter}"
    ${storage_starter}
    if [[ "$?" != "0" ]]; then
        err "failed to start storage with: ${storage_starter}"
        exit 1
    fi
    total_sleep=120
    anmt "$(date) - ${env_name} - sleeping ${total_sleep} seconds to let the storage normalize"
    slp ${total_sleep}
fi


# deploy stacks:
if [[ "${start_ae}" == "1" ]]; then
    if [[ ! -e ${ae_starter} ]]; then
        err "missing path to ae_starter=${ae_starter}"
        exit 1
    fi
    good "$(date) - ${env_name} - starting ae with deployment tool: ${ae_starter} ${path_to_env}"
    ${ae_starter} ${path_to_env}
    if [[ "$?" != "0" ]]; then
        err "$(date) - ${env_name} - failed starting ae with deployment tool: ${ae_starter}"
        exit 1
    fi
else
    anmt "$(date) - ${env_name} - not deploying ae"
fi

inf ""
anmt "start using the ${env_name} cluster with these commands:"
inf "export KUBECONFIG=${KUBECONFIG}"
inf ""
alias_name="k${env_name}"
test_in_bashrc=$(cat ~/.bashrc | grep ${alias_name} | wc -l)
if [[ "${test_in_bashrc}" == "0" ]]; then
    inf "add to your ~/.bashrc as an alias:"
    inf "echo 'alias kdev=\"export KUBECONFIG=${KUBECONFIG}\"' >> ~/.bashrc"
    inf ""
fi

good "done - starting ${env_name} kubernetes vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG} date=$(date)"
anmt "----------------------------------------------"

exit 0
