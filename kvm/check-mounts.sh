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

disk_1_name="${VM_DISK_1_NAME}"
disk_1_mount_path="${VM_DISK_1_MOUNT_PATH}"
disk_2_name="${VM_DISK_2_NAME}"
disk_2_mount_path="${VM_DISK_2_MOUNT_PATH}"
disk_data_dir="${VM_DATA_DIR}"
k8_config_dir="${K8_CONFIG_DIR}"
nodes="${K8_NODES}"
vms="${K8_VMS}"
env_name="${K8_ENV}"

warn "----------------------------------------------"
warn "deleting and formatting disks for ${env_name} vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "disk_1_name=${disk_1_name} mounted inside vm at: ${disk_1_mount_path}"
anmt "disk_2_name=${disk_2_name} mounted inside vm at: ${disk_2_mount_path}"
anmt "External host storing these disk images at: ${disk_data_dir}"
inf ""

if [[ ! -e ${disk_data_dir} ]]; then
    sudo mkdir -p -m 775 ${disk_data_dir}
fi

function check_mounts() {
    anmt "--------------------------------"
    anmt "${env_name} - checking mounts on: ${nodes}"
    anmt "- disk 1: ${disk_1_name} mounted at: ${disk_1_mount_path}"
    anmt "- disk 2: ${disk_2_name} mounted at: ${disk_2_mount_path}"
    for node in $nodes; do
        found_disk_1_is_attached=$(ssh root@${node} "parted -l | grep ${disk_1_name} | awk '{print $2}'")
        found_disk_2_is_attached=$(ssh root@${node} "parted -l | grep ${disk_2_name} | awk '{print $2}'")
        if [[ "${found_disk_1_is_attached}" == "" ]]; then
            err "${env_name}:${node} is missing disk 1 ${disk_1_name} mounted at: ${found_disk_1_is_attached}"
        else
            good "${env_name}:${node} disk 1 - ${disk_1_name} is attached at ${found_disk_1_is_attached}"
        fi
        if [[ "${found_disk_2_is_attached}" == "" ]]; then
            err "${env_name}:${node} is missing disk 2 ${disk_2_name} mounted at: ${found_disk_2_is_attached}"
        else
            good "${env_name}:${node} disk 2 - ${disk_1_name} is ready at ${found_disk_2_is_attached}"
        fi
        err "Fix below:"
        found_disk_1_mount_path=$(ssh root@${node} "parted -l | grep ${disk_1_name} | awk '{print $2}'")
        found_disk_2_mount_path=$(ssh root@${node} "parted -l | grep ${disk_2_name} | awk '{print $2}'")
        if [[ "${found_disk_1_mount_path}" == "" ]]; then
            err "${env_name}:${node} is missing disk 1 ${disk_1_name} mounted at: ${disk_1_mount_path}"
        else
            good "${env_name}:${node} disk 1 - ${disk_1_name} is ready at ${disk_1_mount_path}"
        fi
        if [[ "${found_disk_2_mount_path}" == "" ]]; then
            err "${env_name}:${node} is missing disk 2 ${disk_2_name} mounted at: ${disk_2_mount_path}"
        else
            good "${env_name}:${node} disk 2 - ${disk_1_name} is ready at ${disk_2_mount_path}"
        fi
    done
    anmt "--------------------------------"
}

check_mounts
