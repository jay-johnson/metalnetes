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
disk_1_size="${VM_DISK_1_SIZE}"
disk_1_mount_path="${VM_DISK_1_MOUNT_PATH}"
disk_2_name="${VM_DISK_2_NAME}"
disk_2_size="${VM_DISK_2_SIZE}"
disk_2_mount_path="${VM_DISK_2_MOUNT_PATH}"
disk_3_name="${VM_DISK_3_NAME}"
disk_3_size="${VM_DISK_3_SIZE}"
disk_3_mount_path="${VM_DISK_3_MOUNT_PATH}"
disk_data_dir="${VM_DATA_DIR}"
nodes="${K8_NODES}"
vms="${K8_VMS}"

anmt "----------------------------------------------"
anmt "building disks on ${env_name} kubernetes for vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "disk_1_name=${disk_1_name} ${disk_1_size} mounted inside vm at: ${disk_1_mount_path}"
anmt "disk_2_name=${disk_2_name} ${disk_2_size} mounted inside vm at: ${disk_2_mount_path}"
anmt "disk_3_name=${disk_3_name} ${disk_3_size} mounted inside vm at: ${disk_3_mount_path}"
anmt "External host storing these disk images at: ${disk_data_dir}"
inf ""

if [[ "$(whoami)" == "root" ]]; then
    echo "please run as root to build the disks using qemu"
    exit 1
fi

if [[ ! -e ${disk_data_dir} ]]; then
    sudo mkdir -p -m 775 ${disk_data_dir}
fi

for vm in $vms; do
    node_dir=${disk_data_dir}/${vm}
    if [[ ! -e ${node_dir} ]]; then
        sudo mkdir -p -m 775 ${node_dir}
    fi
    disk_1_path="${node_dir}/k8-centos-${disk_1_name}"
    disk_2_path="${node_dir}/k8-centos-${disk_2_name}"
    disk_3_path="${node_dir}/k8-centos-${disk_3_name}"
    if [[ ! -e "${disk_1_path}" ]]; then
        anmt "creating hdd disk 1 at: ${disk_1_path} size: ${disk_1_size}"
        anmt "qemu-img create -f qcow2 ${disk_1_path} ${disk_1_size}"
        sudo qemu-img create -f qcow2 ${disk_1_path} ${disk_1_size}
        if [[ ! -e ${disk_1_path} ]]; then
            err "missing hdd disk 1 at: ${disk_1_path}"
            err "please generate them manually or using the ./kvm/build-images.sh script"
            exit 1
        fi
    else
        good " - already have image: ${disk_1_path}"
        ls -lrth ${disk_1_path}
    fi
    if [[ ! -e "${disk_2_path}" ]]; then
        anmt "creating hdd disk 2 at: ${disk_2_path} size: ${disk_2_size}"
        anmt "qemu-img create -f qcow2 ${disk_2_path} ${disk_2_size}"
        sudo qemu-img create -f qcow2 ${disk_2_path} ${disk_2_size}
        if [[ ! -e ${disk_2_path} ]]; then
            err "missing hdd disk 2 at: ${disk_2_path}"
            err "please generate them manually or using the ./kvm/build-images.sh script"
            exit 1
        fi
    else
        good " - already have image: ${disk_2_path}"
        ls -lrth ${disk_2_path}
    fi
    if [[ ! -e "${disk_3_path}" ]]; then
        anmt "creating hdd disk 3 at: ${disk_3_path} size: ${disk_3_size}"
        anmt "qemu-img create -f qcow2 ${disk_3_path} ${disk_3_size}"
        sudo qemu-img create -f qcow2 ${disk_3_path} ${disk_3_size}
        if [[ ! -e ${disk_3_path} ]]; then
            err "missing hdd disk 3 at: ${disk_3_path}"
            err "please generate them manually or using the ./kvm/build-images.sh script"
            exit 1
        fi
    else
        good " - already have image: ${disk_3_path}"
        ls -lrth ${disk_3_path}
    fi
done

good "done - building disks on ${env_name} kubernetes for vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
