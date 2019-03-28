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

k8_vm_size="50"
k8_vms_dir="${K8_VMS_DIR}"
k8_vm_bridge="${K8_VM_BRIDGE}"
k8_vm_cpu="${K8_VM_CPU}"
k8_vm_memory="${K8_VM_MEMORY}"

anmt "-----------------------------------------------"
anmt "$(date) - ${env_name} - importing vms from: ${k8_vms_dir}"

vm_files=$(ls ${k8_vms_dir}/*.qcow2)
bridge=${BRIDGE},model=virtio,mac=${MACADDRESS}

for f in ${vm_files}; do
    vm_name=$(echo "${f}" | sed -e 's|/| |g' | awk '{print $NF}' | sed -e 's/\./ /g' | awk '{print $1}')
    anmt "- importing ${vm_name} from ${f}"

    anmt "$(date) - $(pwd) - virt-install --import --name ${vm_name} --memory ${k8_vm_memory} --vcpus ${k8_vm_cpu} --cpu host --disk ${f},device=disk,bus=virtio --network ${bridge} --os-type=linux --os-variant=centos7 --graphics spice,port=-1,listen=localhost --noautoconsole"
    virt-install --import \
        --name ${vm_name} \
        --memory ${k8_vm_memory} \
        --vcpus ${k8_vm_cpu} \
        --cpu host \
        --disk ${f},device=disk,bus=virtio \
        --network ${bridge} \
        --os-type=linux \
        --os-variant=centos7.0 \
        --noautoconsole
    if [[ "$?" != "0" ]]; then
        err "$(date) - failed to import vm: ${vm_name}"
        err "virt-install --import --name ${vm_name} --memory ${k8_vm_memory} --vcpus ${k8_vm_cpu} --cpu host --disk ${k8_vm_size},format=qcow2,bus=virtio --network ${bridge} --os-type=linux --os-variant=centos7 --graphics spice,port=-1,listen=localhost --noautoconsole"
        exit 1
    fi
done

anmt "done - $(date) - ${env_name} - importing vms from: ${k8_vms_dir}"
anmt "-----------------------------------------------"

exit 0
