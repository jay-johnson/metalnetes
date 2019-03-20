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

# this assumes the current user has root ssh access to the following hosts:
initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
env_name="${K8_ENV}"
k8_config_dir="${K8_CONFIG_DIR}"
k8_tools_dir="${K8_TOOLS_DIR}"
login_user="${LOGIN_USER}"
local_vm_src_tools="${LOCAL_VM_SRC_TOOLS}"
local_os_dir="${LOCAL_OS_DIR}"

include_cluster_config="export CLUSTER_CONFIG=${k8_config_dir}/k8.env"

start_date=$(date)

anmt "---------------------------------------------------------"
anmt "${env_name} - deploying all files to kubernetes cluster nodes: ${nodes}"
anmt "KUBECONFIG=${KUBECONFIG}"
inf ""

for i in $nodes; do
    anmt "${env_name}:${i} - creating directories: ${k8_config_dir} ${k8_tools_dir}"
    ssh ${login_user}@${i} "chmod 775 /opt && mkdir -p -m 775 ${k8_config_dir} && mkdir -p -m 775 ${k8_tools_dir}"
    anmt "${env_name}:${i} - copying ${local_vm_src_tools} on all nodes: ${k8_tools_dir}"
    scp -r -q ${local_vm_src_tools}/* ${login_user}@${i}:${k8_tools_dir}/
    anmt "${env_name}:${i} - copying ${local_vm_src_tools} on all nodes: ${k8_config_dir}"
    scp -r -q ${local_os_dir}/* ${login_user}@${i}:${k8_config_dir}/
    echo "${env_name}:${i} - copying ${path_to_env} to ${i}:${k8_config_dir}/k8.env"
    scp -q ${path_to_env} ${login_user}@${i}:${k8_config_dir}/k8.env
done

good "done - ${env_name} - deploying all files to kubernetes cluster nodes: ${nodes}"
anmt "---------------------------------------------------------"

exit 0
