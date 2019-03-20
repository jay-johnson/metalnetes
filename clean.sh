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
remote_tool_cni_reset="${REMOTE_TOOL_CNI_RESET}"
remote_tool_update_k8="${REMOTE_TOOL_UPDATE_K8}"
remote_tool_install_go="${REMOTE_TOOL_INSTALL_GO}"
remote_tool_install_htop="${REMOTE_TOOL_INSTALL_HTOP}"
remote_tool_user_install_kubeconfig="${REMOTE_TOOL_USER_INSTALL_KUBECONFIG}"
remote_tool_node_reset="${REMOTE_TOOL_NODE_RESET}"
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
delete_docker="${DELETE_DOCKER}"
debug="${METAL_DEBUG}"

include_cluster_config="export CLUSTER_CONFIG=${k8_config_dir}/k8.env"
ingress_type="${INGRESS_TYPE}"
start_ingress="${START_INGRESS}"
tool_nginx_starter="$(dirname ${path_to_env})/nginx/run.sh"
rook_ceph_uninstall="$(dirname ${path_to_env})/rook-ceph/_uninstall.sh"

for i in "$@"
do
    contains_equal=$(echo ${i} | grep "=")
    if [[ "${i}" == "-d" ]]; then
        debug="1"
    elif [[ "${i}" == "deletedocker" ]]; then
        delete_docker="1"
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

anmt "${env_name} - deploying files with: ${deploy_tool}"
${deploy_tool}
if [[ "$?" != "0" ]]; then
    err "failed deploying files to nodes: ${nodes} with: ${deploy_tool}"
    exit 1
fi

anmt "${env_name} - uninstalling rook-ceph with: ${rook_ceph_uninstall}"
${rook_ceph_uninstall} >> /dev/null 2>&1

anmt "${env_name} - install cni on nodes: ${tool_cni_installer}"
for i in $nodes; do
    echo "installing CNI loopback plugin: ssh ${login_user}@${i} \"${include_cluster_config}; ${tool_cni_installer}"
    ssh ${login_user}@${i} "${include_cluster_config}; ${tool_cni_installer}"
done
inf ""

for i in $nodes; do
    anmt "${env_name} - resetting flannel networking on ${i}: ssh ${login_user}@${i} '${include_cluster_config} && ${remote_tool_cni_reset}'"
    ssh ${login_user}@${i} "${include_cluster_config} && ${remote_tool_cni_reset}"
    if [[ "$?" != "0" ]]; then
        err "failed to reset flannel cni on ${i} using: ssh ${login_user}@${i} \"${include_cluster_config} && ${remote_tool_cni_reset}\""
        exit 1
    fi
done
inf ""

# https://blog.heptio.com/properly-resetting-your-kubeadm-bootstrapped-cluster-nodes-heptioprotip-473bd0b824aa
for i in $nodes; do
    anmt "resetting iptables on ${i}: ssh ${login_user}@${i} 'iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X'"
    ssh ${login_user}@${i} "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X"
done
inf ""

if [[ "${delete_docker}" == "1" ]]; then
    for i in $nodes; do
        anmt "stopping docker on ${i}: ssh ${login_user}@${i} 'systemctl stop docker'"
        ssh ${login_user}@${i} "systemctl stop docker"
    done
    inf ""

    for i in $nodes; do
        anmt "cleaning up docker directories on ${i}: ssh ${login_user}@${i} 'rm -rf ${docker_data_dir}'"
        ssh ${login_user}@${i} "rm -rf ${docker_data_dir} >> /dev/null 2>&1"
    done
    inf ""
fi

for i in $nodes; do
    anmt "starting docker on ${i}: ssh ${login_user}@${i} 'systemctl start docker; docker ps"
    ssh ${login_user}@${i} "systemctl start docker; docker ps"
done

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
scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}
inf ""

for i in ${nodes}; do
    anmt "installing kubernetes config on ${i} using: scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${login_user}@${i}:${KUBECONFIG}"
    scp ${KUBECONFIG} ${login_user}@${i}:${KUBECONFIG}
    if [[ "$?" != "0" ]]; then
        err "${env_name}:${i} failed deploying KUBECONFIG to ${KUBECONFIG}"
        exit 1
    fi
    scp ${KUBECONFIG} ${login_user}@${i}:/etc/kubernetes/admin.conf
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

anmt "copying kubernetes config locally: scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}"
scp ${login_user}@${initial_master}:/etc/kubernetes/admin.conf ${KUBECONFIG}
if [[ "$?" != "0" ]]; then
    err "${env_name} - failed to copy ${KUBECONFIG} locally"
    exit 1
fi
inf ""

sleep 60

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