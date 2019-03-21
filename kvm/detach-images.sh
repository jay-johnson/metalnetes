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

# defined in the CLUSTER_CONFIG
start_logger

disk_1_name="${VM_DISK_1_NAME}"
disk_1_mount_path="${VM_DISK_1_MOUNT_PATH}"
disk_2_name="${VM_DISK_2_NAME}"
disk_2_mount_path="${VM_DISK_2_MOUNT_PATH}"
disk_3_name="${VM_DISK_3_NAME}"
disk_3_mount_path="${VM_DISK_3_MOUNT_PATH}"
disk_data_dir="${VM_DATA_DIR}"
nodes="${K8_NODES}"
vms="${K8_VMS}"

anmt "----------------------------------------------"
anmt "detaching disks on ${env_name} kubernetes to vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "disk_1_name=${disk_1_name} mounted inside vm at: ${disk_1_mount_path}"
anmt "disk_2_name=${disk_2_name} mounted inside vm at: ${disk_2_mount_path}"
anmt "disk_3_name=${disk_3_name} mounted inside vm at: ${disk_3_mount_path}"
anmt "External host storing these disk images at: ${disk_data_dir}"
inf ""

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
    if [[ ! -e ${disk_1_path} ]]; then
        err "missing hdd disk 1 at: ${disk_1_path}"
        err "please generate them manually or using the ./kvm/build-images.sh script"
        exit 1
    elif [[ ! -e ${disk_2_path} ]]; then
        err "missing hdd disk 2 at: ${disk_2_path}"
        err "please generate them manually or using the ./kvm/build-images.sh script"
        exit 1
    elif [[ ! -e ${disk_3_path} ]]; then
        err "missing hdd disk 3 at: ${disk_3_path}"
        err "please generate them manually or using the ./kvm/build-images.sh script"
        exit 1
    else
        anmt "detaching image: ${disk_1_path} from ${vm} with:"
        anmt "virsh detach-disk ${vm} \
            ${disk_1_path} \
            --persistent"
        virsh detach-disk ${vm} \
            ${disk_1_path} \
            --persistent
        anmt "detaching image: ${disk_2_path} from ${vm} with:"
        anmt "virsh detach-disk ${vm} \
            ${disk_2_path} \
            --persistent"
        virsh detach-disk ${vm} \
            ${disk_2_path} \
            --persistent
        anmt "detaching image: ${disk_3_path} from ${vm} with:"
        anmt "virsh detach-disk ${vm} \
            ${disk_3_path} \
            --persistent"
        virsh detach-disk ${vm} \
            ${disk_3_path} \
            --persistent
    fi
done

good "done - detaching disks on ${env_name} kubernetes for vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
