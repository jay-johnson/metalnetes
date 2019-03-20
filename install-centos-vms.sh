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
tool_dns_etc_resolv="${TOOL_DNS_ETC_RESOLV}"
k8_dns_server_1="${K8_DNS_SERVER_1}"
k8_domain="${K8_DOMAIN}"
login_user="${LOGIN_USER}"
debug="${METAL_DEBUG}"
local_vm_src_tools="${LOCAL_VM_SRC_TOOLS}"
local_os_dir="${LOCAL_OS_DIR}"
tool_dns_etc_resolv="${TOOL_DNS_ETC_RESOLV}"
remote_vm_installer="${REMOTE_VM_INSTALLER}"
remote_tool_cni_installer="${REMOTE_TOOL_CNI_INSTALLER}"
remote_tool_install_go="${REMOTE_TOOL_INSTALL_GO}"
remote_tool_install_htop="${REMOTE_TOOL_INSTALL_HTOP}"
start_registry="${START_REGISTRY}"
registry_user="${REGISTRY_USER}"
registry_password="${REGISTRY_PASSWORD}"
registry_address="${REGISTRY_ADDRESS}"
install_go="${INSTALL_GO}"
install_htop="${INSTALL_HTOP}"
include_cluster_config="export CLUSTER_CONFIG=${k8_config_dir}/k8.env"

start_date=$(date)
anmt "---------------------------------------------------------"
anmt "${start_date} - setting up ${env_name} on nodes: ${nodes} DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
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
    echo "installing CNI loopback plugin: ssh ${login_user}@${i} \"${include_cluster_config}; ${k8_tools_dir}/install-cni.sh\""
    ssh ${login_user}@${i} "${include_cluster_config}; ${k8_tools_dir}/install-cni.sh"
done

anmt "${env_name} - running /etc/resolv.conf installer: ${tool_dns_etc_resolv} DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
${tool_dns_etc_resolv}
if [[ "$?" != "0" ]]; then
    err "failed to set /etc/resolv.conf on ${env_name} nodes=${nodes} with: ${tool_dns_etc_resolv}"
    exit 1
fi

for i in $nodes; do
    anmt "${env_name}:${i} - running: ${include_cluster_config}; ${remote_vm_installer}"
    ssh ${login_user}@${i} "${include_cluster_config}; ${remote_vm_installer}"
    if [[ "$?" != "0" ]]; then
        err "failed preparing ${env_name}:${i} to run kubernetes"
        echo "ssh ${login_user}@${i} \"${include_cluster_config}; ${remote_vm_installer}\""
        exit 1
    fi
    anmt "${env_name}:${i} - finished running ${remote_vm_installer}"
    ssh ${login_user}@${i} "${include_cluster_config}; ${k8_tools_dir}/prepare.sh"
    if [[ "$?" != "0" ]]; then
        err "failed running ${k8_config_dir}/prepare.sh on ${env_name}:${i}"
        echo "ssh ${login_user}@${i} \"${include_cluster_config}; ${k8_tools_dir}/prepare.sh"
        exit 1
    fi
    anmt "${env_name}:${i} - finished running ${k8_tools_dir}/prepare.sh"
    anmt "---------"
done

anmt "${env_name} running /etc/resolv.conf installer: ${tool_dns_etc_resolv} DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
${tool_dns_etc_resolv}
if [[ "$?" != "0" ]]; then
    err "failed to set /etc/resolv.conf on ${env_name} nodes=${nodes} with: ${tool_dns_etc_resolv}"
    exit 1
fi

if [[ "${start_registry}" == "1" ]]; then
    registry_user="${REGISTRY_USER}"
    registry_password="${REGISTRY_PASSWORD}"
    registry_address="${REGISTRY_ADDRESS}"
    for i in $nodes; do
        anmt "${env_name}:${i} - restarting docker"
        ssh ${login_user}@${i} "systemctl restart docker && sleep 5"
        command="echo \"${registry_password}\" | docker login --username ${registry_user} --password-stdin ${registry_address} >> /dev/null 2>&1"
        anmt "${env_name}:${i} - logging into private docker registry with command: ${command}"
        ssh ${login_user}@${i} "${command}"
        if [[ "$?" != "0" ]]; then
            err "failed logging into private docker registry for ${env_name} on nodes=${nodes} with: ${command}"
            exit 1
        fi
    done
fi

if [[ "${install_go}" == "1" ]]; then
    for i in $nodes; do
        anmt "installing go on ${i}: ssh ${login_user}@${i} '${remote_tool_install_go}'"
        ssh ${login_user}@${i} "${remote_tool_install_go}"
    done
    inf ""
fi

if [[ "${install_htop}" == "1" ]]; then
    for i in $nodes; do
        anmt "installing htop on ${i}: ssh ${login_user}@${i} '${remote_tool_install_htop}'"
        ssh ${login_user}@${i} "${include_cluster_config}; ${remote_tool_install_htop}"
    done
    inf ""
fi

end_date=$(date)
anmt "started on: ${start_date}"
anmt "ended on:   ${end_date}"
inf ""
good "done - ${start_date} - setting up ${env_name} on nodes: ${nodes}"
anmt "---------------------------------------------------------"

exit 0
