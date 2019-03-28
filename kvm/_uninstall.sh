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

env_name="${K8_ENV}"
nodes="${K8_NODES}"
vms="${K8_VMS}"
tools_dir="$(dirname ${path_to_env})"
vm_manage="${tools_dir}/kvm/vm-manage.sh"

anmt "----------------------------------------------"
anmt "${env_name} - building kubernetes vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG} and manage tool: ${vm_manage}"
inf ""

if [[ ! -e ${KVM_IMAGES_DIR} ]]; then
    mkdir -p -m 775 ${KVM_IMAGES_DIR}
fi
if [[ ! -e ${KVM_VMS_DIR} ]]; then
    mkdir -p -m 775 ${KVM_VMS_DIR}
fi

overwrite=1
vm_num=1
for vm in $vms; do
    mac=""
    anmt "${env_name}:${vm} - remove vm=${vm_num} with ${vm_manage}"
    ${vm_manage} remove ${vm}
    if [[ -e ${KVM_VMS_DIR}/${vm} ]]; then
        anmt " - deleting vm storage: ${KVM_VMS_DIR}/${vm}"
        sudo rm -rf ${KVM_VMS_DIR}/${vm}
    fi
    (( vm_num++ ))
done

good "done - removing ${env_name} kubernetes vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
