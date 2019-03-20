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
disk_3_name="${VM_DISK_3_NAME}"
disk_3_mount_path="${VM_DISK_3_MOUNT_PATH}"
disk_data_dir="${VM_DATA_DIR}"
k8_config_dir="${K8_CONFIG_DIR}"
nodes="${K8_NODES}"
vms="${K8_VMS}"

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
    warn "--------------------------------"
    warn "${env_name} - checking mounted ${dev_path} paths on the cluster vms"
    for node in $nodes; do
        anmt "${node} fdisk -l"
        ssh root@${node} "fdisk -l"
        anmt "--------------------------------"
    done
}

function delete_partitions_and_reformat_disks() {

    node=${1}
    dev_path=${2}
    mount_path=${3}
    dev_name=${4}
    label=${5}
    partition_name="${dev_path}1"

    warn "--------------------------------"
    warn "${env_name}:${node} - deleting ${dev_name}:${dev_path} label ${label} on all ${nodes} and removing partitions"

    # unmount device if mounted
    anmt "${node} - ${dev_path}:${mount_path} umount"
    ssh root@${node} "umount ${mount_path}"
    ssh root@${node} "umount ${dev_path}2"
    ssh root@${node} "umount ${dev_path}1"
    ssh root@${node} "umount ${dev_path}"

    # delete partitions
    anmt "${node} - deleting partitions"
    anmt "ssh root@${node} \"parted ${dev_path} rm 1\""
    ssh root@${node} "parted ${dev_path} rm 1"
    anmt "ssh root@${node} \"parted ${dev_path} rm 2\""
    ssh root@${node} "parted ${dev_path} rm 2"

    # good "${node} - using parted to partition ${dev_path}"
    # https://unix.stackexchange.com/questions/38164/create-partition-aligned-using-parted/49274#49274
    ssh root@${node} "parted ${dev_path} --script -- mklabel gpt"
    anmt "ssh root@${node} \"parted -s -a optimal ${dev_path} mkpart ${label} 0% 100%\""
    ssh root@${node} "parted -s -a optimal ${dev_path} mkpart ${label} 0% 100%"
    # sleep 2

    # anmt "${node} - checking ${dev_path} partitions"
    # check_if_partitioned=$(ssh root@${node} "parted -s ${dev_path} print | grep -A 10 Number | grep -E 'MB|GB' | wc -l")
    # if [[ "${check_if_partitioned}" != "1" ]]; then
    #    err "Failed automated parted partitioning - please manually delete ${dev_path} partitions on ${node} with the commands and retry: "
    #    ssh root@${node} "parted ${dev_path} print"
    #    anmt "ssh root@${node}"
    #    anmt "parted ${dev_path}"
    #    exit 1
    # fi

    # ceph recommends xfs filesystems
    # http://docs.ceph.com/docs/jewel/rados/configuration/filesystem-recommendations/
    anmt "${node} - formatting ${partition_name} as xfs"
    ssh root@${node} "mkfs.xfs -f ${dev_path}1"

    anmt "${node} - removing previous mountpoint if exists: ${mount_path}"
    ssh root@${node} "rm -rf ${mount_path}"

    anmt "${node} - creating ${partition_name} mountpoint: ${mount_path}"
    ssh root@${node} "mkdir -p -m 775 ${mount_path}"

    # ssh root@${node} "umount ${dev_path}1"
    anmt "${node} - mounting ${partition_name} to ${mount_path}"
    ssh root@${node} "mount ${partition_name} ${mount_path}"

    check_disk_filesystem=$(ssh root@${node} "df -Th ${mount_path} | grep ${dev_name} | grep xfs | wc -l")
    if [[ "${check_disk_filesystem}" == "0" ]]; then
        err "Failed to mount device: ${dev_name} path: ${dev_path} ${node}:${partition_name} as xfs filesystem to ${mount_path}"
        anmt "Please fix this node and retry:"
        anmt "ssh root@${node} \"mount ${partition_name} ${mount_path}\""
    fi

    test_exists=$(ssh root@${node} "cat /etc/fstab | grep ${dev_name} | grep xfs | wc -l")
    if [[ "${test_exists}" == "0" ]]; then
        anmt "archiving: ssh root@${node} "cp /etc/fstab ${k8_config_dir}/.fstab_back_after_${dev_name}\"
        ssh root@${node} "cp /etc/fstab ${k8_config_dir}/.fstab_back_after_${dev_name}"
        anmt "adding ${dev_name} to /etc/fstab"
        ssh root@${node} "echo \"${partition_name} ${mount_path}  xfs     defaults    0 0\" >> /etc/fstab"
    fi

    anmt "${node} - checking mounts"
    ssh root@${node} "parted -l | grep ${dev_path}"
    anmt "--------------------------------------------"
}

devices_per_vm=""
mount_paths="${disk_1_mount_path} ${disk_2_mount_path}"
for node in $nodes; do
    ceph_disk_device_path=$(ssh root@${node} "parted -l | grep 107GB | grep dev | awk '{print \$2}' | sed -e 's/://g'")
    rook_disk_device_path=$(ssh root@${node} "parted -l | grep 21.5GB | grep dev | awk '{print \$2}' | sed -e 's/://g'")
    osd_disk_device_path=$(ssh root@${node} "parted -l | grep 161GB | grep dev | awk '{print \$2}' | sed -e 's/://g'")

    if [[ "${ceph_disk_device_path}" != "" ]]; then
        use_name=$(echo "${ceph_disk_device_path}" | sed -e 's|/| |g' | awk '{print $NF}')
        delete_partitions_and_reformat_disks ${node} ${ceph_disk_device_path} /var/lib/ceph ${use_name} ceph
    fi
    if [[ "${rook_disk_device_path}" != "" ]]; then
        use_name=$(echo "${rook_disk_device_path}" | sed -e 's|/| |g' | awk '{print $NF}')
        delete_partitions_and_reformat_disks ${node} ${rook_disk_device_path} /var/lib/rook ${use_name} rook
    fi

    anmt "${env_name} - deleting disk 3 partitions used by rook-ceph osd: ${osd_disk_device_path}"
    ssh root@${node} "umount ${osd_disk_device_path}1"
    ssh root@${node} "umount ${osd_disk_device_path}"
    ssh root@${node} "parted ${osd_disk_device_path} rm 1"
    ssh root@${node} "parted ${osd_disk_device_path} rm 2"
done

exit 1

check_mounts

good "good - deleting and formatting disks for ${env_name} vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
