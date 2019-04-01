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

# this assumes the current user has root ssh access to the following hosts:
initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
env_name="${K8_ENV}"
k8_config_dir="${K8_CONFIG_DIR}"
k8_tools_dir="${K8_TOOLS_DIR}"
k8_join_cluster_tool="${K8_JOIN}"
login_user="${LOGIN_USER}"
docker_data_dir="${DOCKER_DATA_DIR}"
deploy_ssh_key="${DEPLOY_SSH_KEY}"
tool_node_labeler="${TOOL_NODE_LABELER}"
remote_tool_reset_vm="${REMOTE_TOOL_HARD_RESET_VM}"
remote_tool_update_k8="${REMOTE_TOOL_UPDATE_K8}"
remote_tool_install_go="${REMOTE_TOOL_INSTALL_GO}"
remote_tool_install_htop="${REMOTE_TOOL_INSTALL_HTOP}"
remote_tool_user_install_kubeconfig="${REMOTE_TOOL_USER_INSTALL_KUBECONFIG}"
remote_tool_prepare_to_run_kube="${REMOTE_TOOL_VM_PREPARE}"
tool_cni_installer="${REMOTE_TOOL_CNI_INSTALLER}"
tool_cni_starter="${TOOL_CNI_STARTER}"
tool_unlock_nodes="${TOOL_UNLOCK_NODES}"
install_go="${INSTALL_GO}"
install_htop="${INSTALL_HTOP}"
local_vm_src_tools="${LOCAL_VM_SRC_TOOLS}"
local_os_dir="${LOCAL_OS_DIR}"
start_helm="${START_HELM}"
helm_starter="${HELM_STARTER}"
tiller_starter="${TILLER_STARTER}"
prepare_mode="${PREPARE_MODE}"
use_labels="${USE_LABELS}"
update_kube="${UPDATE_KUBE}"
deploy_tool="${TOOL_DEPLOY_FILES}"
disk_1_mount_path="${VM_DISK_1_MOUNT_PATH}"
disk_2_mount_path="${VM_DISK_2_MOUNT_PATH}"
storage_type="${STORAGE_TYPE}"
remote_vm_installer="${REMOTE_VM_INSTALLER}"
debug="${METAL_DEBUG}"

include_cluster_config="${RUN_ON_CLUSTER_VM}"
ingress_type="${INGRESS_TYPE}"
start_ingress="${START_INGRESS}"
tool_nginx_starter="$(dirname ${path_to_env})/nginx/run.sh"
rook_ceph_uninstall="$(dirname ${path_to_env})/rook-ceph/_uninstall.sh"

for i in "$@"
do
    contains_equal=$(echo ${i} | grep "=")
    if [[ "${i}" == "-d" ]]; then
        debug="1"
    elif [[ "${i}" == "noinstallgo" ]]; then
        install_go="0"
    elif [[ "${contains_equal}" != "" ]]; then
        first_arg=$(echo ${i} | sed -e 's/=/ /g' | awk '{print $1}')
        second_arg=$(echo ${i} | sed -e 's/=/ /g' | awk '{print $2}')
        if [[ "${first_arg}" == "labeler" ]]; then
            tool_node_labeler=${second_arg}
        elif [[ "${first_arg}" == "uselabels" ]]; then
            use_labels=${second_arg}
        elif [[ "${first_arg}" == "dockerdir" ]]; then
            docker_data_dir=${second_arg}
        fi
    fi
done


start_date=$(date)
anmt "---------------------------------------------------------"
anmt "${start_date} - cleaning kubernetes cluster ${env_name} to nodes: ${nodes}"
anmt "KUBECONFIG=${KUBECONFIG}"
inf ""

if [[ ! -e $(dirname ${KUBECONFIG}) ]]; then
    mkdir -p -m 775 $(dirname ${KUBECONFIG})
fi

if [[ "${install_go}" == "1" ]]; then
    for i in $nodes; do
        anmt "installing go on ${i}: ssh ${login_user}@${i} '${remote_tool_install_go}'"
        ssh ${login_user}@${i} "${include_cluster_config} && ${remote_tool_install_go}"
    done
    inf ""
fi

if [[ "${install_htop}" == "1" ]]; then
    for i in $nodes; do
        anmt "installing htop on ${i}: ssh ${login_user}@${i} '${remote_tool_install_htop}'"
        ssh ${login_user}@${i} "${include_cluster_config} && ${remote_tool_install_htop}"
    done
    inf ""
fi

if [[ "${update_kube}" == "1" ]]; then
    for i in $nodes; do
        anmt "updating k8 on ${env_name}:${i} - ssh ${login_user}@${i} '${remote_tool_update_k8}'"
        ssh ${login_user}@${i} "${include_cluster_config} && ${remote_tool_update_k8}"
    done
    inf ""
fi

# Deploy files to nodes

anmt "${env_name} - deploying files with: ${deploy_tool}"
${deploy_tool}
if [[ "$?" != "0" ]]; then
    err "failed deploying files to nodes: ${nodes} with: ${deploy_tool}"
    exit 1
fi

anmt "${env_name} - uninstalling rook-ceph with: ${rook_ceph_uninstall}"
${rook_ceph_uninstall}

# resetting VMs in the cluster with default: ${REPO_BASE_DIR}/tools/reset-k8-and-docker-and-cni-on-vm.sh

anmt "${env_name} - resetting cluster vms: ${remote_tool_reset_vm}"
for i in $nodes; do
    anmt "${env_name} - resetting node: ${i} using: ssh ${login_user}@${i} '${include_cluster_config} && ${remote_tool_reset_vm}'"
    ssh ${login_user}@${i} "${include_cluster_config} && ${remote_tool_reset_vm}"
    if [[ "$?" != "0" ]]; then
        err "failed to reset node: ${i} using: ssh ${login_user}@${i} \"${include_cluster_config} && ${remote_tool_reset_vm}\""
        exit 1
    fi
done
inf ""

if [[ "${storage_type}" == "rook-ceph-block-distributed" ]]; then
    anmt "${env_name} cleaning up disks: ${disk_1_mount_path} ${disk_2_mount_path}"
    for i in $nodes; do
        if [[ "${disk_1_mount_path}" != "" ]] && [[ "${disk_1_mount_path}" != "/" ]]; then
            anmt "- ${env_name}:${i} - deleting disk 1 dir: ${disk_1_mount_path}"
            ssh ${login_user}@${i} "rm -rf ${disk_1_mount_path}/* >> /dev/null 2>&1"
        fi
        if [[ "${disk_2_mount_path}" != "" ]] && [[ "${disk_2_mount_path}" != "/" ]]; then
            anmt "- ${env_name}:${i} - deleting disk 2 dir: ${disk_2_mount_path}"
            ssh ${login_user}@${i} "rm -rf ${disk_2_mount_path}/* >> /dev/null 2>&1"
        fi
    done
fi

anmt "starting cluster initial master node on ${initial_master} in ${k8_tools_dir}: cd ${k8_tools_dir}; ${include_cluster_config} ; export KUBECONFIG=/etc/kubernetes/admin.conf && ${remote_tool_prepare_to_run_kube}"
for i in ${nodes}; do
    ssh ${login_user}@${i} "cd ${k8_tools_dir}; ${include_cluster_config} ; export KUBECONFIG=/etc/kubernetes/admin.conf && ${remote_tool_prepare_to_run_kube}"
done
inf ""

anmt "copying kubernetes config to local using: scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}"
scp -q ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}
inf ""

for i in ${nodes}; do
    anmt "installing kubernetes config on ${i} using: scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${login_user}@${i}:${KUBECONFIG}"
    scp -q ${KUBECONFIG} ${login_user}@${i}:${KUBECONFIG}
    if [[ "$?" != "0" ]]; then
        err "${env_name}:${i} failed deploying KUBECONFIG to ${KUBECONFIG}"
        exit 1
    fi
    scp -q ${KUBECONFIG} ${login_user}@${i}:/etc/kubernetes/admin.conf
    if [[ "$?" != "0" ]]; then
        err "${env_name}:${i} failed deploying KUBECONFIG to /etc/kubernetes/admin.conf"
        exit 1
    fi
done
inf ""

anmt "starting ${env_name} join: ${k8_join_cluster_tool}"
${k8_join_cluster_tool}
if [[ "$?" != "0" ]]; then
    err "${env_name} cluster failed joining all kubernetes nodes"
    exit 1
fi

# deploy the KUBECONFIG to the K8_CONFIG_DIR on all nodes
# includes directory creation if not found
# use the bash function 'metal' to toggle between multiple
# clusters using different k8.env files
anmt "deploying ${env_name}:${path_to_env} with bash-supported deploy function: metal"
metal

# shutdown if metal install failed
if [[ "$?" != "0" ]]; then
    err "${env_name} - failed to copy ${KUBECONFIG} locally"
    exit 1
fi
if [[ ! -e ${KUBECONFIG} ]]; then
    err "${env_name} - failed to find newly created ${KUBECONFIG} locally"
    err "tried to copy the config with: scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}"
    exit 1
fi
inf ""

anmt "${env_name} - sleeping to let the cluster nodes join with new KUBECONFIG=${KUBECONFIG}"
slp 60

if [[ -e ${tool_node_labeler} ]]; then
    anmt "applying ${env_name} labels using command: ${tool_node_labeler} ${use_labels}"
    ${tool_node_labeler} ${use_labels}
    inf ""
fi

anmt "scheduling ${env_name} on nodes: ${nodes} with: ${tool_unlock_nodes}"
${tool_unlock_nodes}
if [[ "$?" != "0" ]]; then
    err "${env_name} failed setting scheduling: ${tool_unlock_nodes}"
    exit 1
fi

anmt "starting ${env_name} CNI: ${tool_cni_starter} with KUBECONFIG=${KUBECONFIG}"
${tool_cni_starter}
if [[ "$?" != "0" ]]; then
    err "${env_name} failed starting CNI: ${tool_cni_starter}"
    exit 1
fi

sleep 10

anmt "getting ${env_name} cluster status with KUBECONFIG=${KUBECONFIG}"
kubectl get nodes -o wide --show-labels
inf ""

anmt "getting ${env_name} cluster scheduling KUBECONFIG=${KUBECONFIG}"
inf ""

if [[ "${start_ingress}" == "1" ]]; then
    if [[ "${ingress_type}" == "nginx" ]]; then
        if [[ -e ${tool_nginx_starter} ]]; then
            anmt "starting ${env_name} nginx ingress with ${tool_nginx_starter} and KUBECONFIG=${KUBECONFIG}"
            ${tool_nginx_starter}
            if [[ "$?" != "0" ]]; then
                err "failed starting ${env_name} nginx ingress with ${tool_nginx_starter} and KUBECONFIG=${KUBECONFIG}"
                exit 1
            fi
        else
            err "failed ${env_name} finding nginx ingress ${tool_nginx_starter}"
            exit 1
        fi
    fi
else
    good "no ingress deployed for START_INGRESS=${start_ingress}"
fi

end_date=$(date)
anmt "started on: ${start_date}"
anmt "ended on:   ${end_date}"
anmt "done - cleaning kubernetes cluster ${env_name} to nodes: ${nodes}"
anmt "---------------------------------------------------------"

anmt "start using the cluster with:"
echo ""
echo "export KUBECONFIG=${KUBECONFIG}"
echo "kubectl get nodes -o wide"
echo ""
exit 0
