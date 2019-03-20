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

env_name=${K8_ENV}
bridge=${K8_VM_BRIDGE}
vms="${K8_VMS}"
vm_dir="$(dirname ${path_to_env})/centos"
vm_file="${vm_dir}/kvm.env"

anmt "----------------------------------"
anmt "${env_name} - detecting all ips on ${bridge} with: ${nodes}"
anmt "saving to: ${vm_file}"

echo "# ${env_name} generated on: $(date)" > ${vm_file}

vm_num=1
all_ips=$(sudo arp-scan -q -l --interface ${bridge})
for vm in ${vms}; do
    # anmt "- ${env_name}:${vm} vm ${vm_num}"
    mac_address=$(virsh dumpxml ${vm} | grep 'mac address' | sed -e "s/'/ /g" | awk '{print $3}')
    if [[ "${mac_address}" == "" ]]; then
        err "- failed finding ${env_name}:${vm} mac address"
    else
        vm_ip=$(echo "${all_ips}" | grep ${mac_address} | awk '{print $1}')
        if [[ "${vm_ip}" == "" ]]; then
            err "- failed finding vm ${vm_num} on ${env_name} with name: ${vm} using ${bridge} device ${ip}"
        else
            good "found vm ${vm_num}: ${vm}@${vm_ip} using ${mac_address}"
            echo "export VM_NAME_${vm_num}=${vm}" >> ${vm_file}
            echo "export VM_MAC_${vm_num}=${mac_address}" >> ${vm_file}
            echo "export VM_IP_${vm_num}=${vm_ip}" >> ${vm_file}
            echo "export VM_ENV_${vm_num}=${env_name}" >> ${vm_file}
        fi
    fi
    (( vm_num++ ))
done

anmt "manage the vms using the vm_file:"
anmt "source ${vm_file}"

good "done - ${env_name} - detecting all ips on ${bridge} with: sudo arp-scan -q -l --interface ${bridge}"
anmt "----------------------------------"
