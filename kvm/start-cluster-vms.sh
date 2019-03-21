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
vm_cloud_init="${tools_dir}/kvm/cloud-init-script.sh"
vm_build_network_env="${tools_dir}/kvm/find-vms-on-bridge.sh"

anmt "----------------------------------------------"
anmt "${env_name} - building kubernetes vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG} and manage tool: ${vm_manage}"
inf ""

if [[ "$(whoami)" == "root" ]]; then
    echo "please run as root to build the disks using qemu"
    exit 1
fi

if [[ ! -e ${KVM_IMAGES_DIR} ]]; then
    mkdir -p -m 775 ${KVM_IMAGES_DIR}
fi
if [[ ! -e ${KVM_VMS_DIR} ]]; then
    mkdir -p -m 775 ${KVM_VMS_DIR}
fi

overwrite=1
vm_num=1
for vm in $vms; do
    cpu="${K8_VM_CPU}"
    memory="${K8_VM_MEMORY}"
    ip="${K8_VM_IP_1}"
    mac="${K8_VM_MAC_1}"
    dns="${K8_DNS_SERVER_1}"
    size="${K8_VM_SIZE}"
    user="${K8_VM_USER}"
    ssh_key=""
    timezone="${K8_VM_TZ}"
    domain="${K8_DOMAIN}"
    fqdn=$(echo "${K8_NODES}" | awk '{print $1}')
    bridge="${K8_VM_BRIDGE}"
    vm_type="k8"
    # https://coreos.com/os/docs/latest/cloud-config-examples.html
    script=""
    if [[ "${vm_num}" == "2" ]]; then
        ip="${K8_VM_IP_2}"
        mac="${K8_VM_MAC_2}"
        fqdn=$(echo "${K8_NODES}" | awk '{print $2}')
    elif [[ "${vm_num}" == "3" ]]; then
        ip="${K8_VM_IP_3}"
        mac="${K8_VM_MAC_3}"
        fqdn=$(echo "${K8_NODES}" | awk '{print $3}')
    fi
    if [[ -e "${HOME}/.ssh/known_hosts" ]]; then
        anmt "${env_name}:${vm} - removing any previous ssh known_hosts entries for ${IP} to prevent automation issues"
        ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${IP}" >> /dev/null 2>&1
        ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm}" >> /dev/null 2>&1
        ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm}.${domain}" >> /dev/null 2>&1
    fi
    if [[ "${overwrite}" == "1" ]] || [[ ! -e "${KVM_VMS_DIR}/${vm}" ]]; then
        export IP="${ip}"
        export MAC="${mac}"
        export FQDN="${fqdn}"
        export GATEWAY="${K8_GATEWAY}"
        anmt "${env_name}:${vm} - creating ${vm_type} vm=${vm_num} with ${vm_manage}"
        anmt "${vm} ${fqdn} ${size}G ${ip} ${mac} ${dns} bridge=${bridge}"
        anmt "${vm} cpu=${cpu} memory=${memory} user=${user} ${domain}"
        anmt "${vm_manage} create -M \"${mac}\" -c ${cpu} -d ${size} -m ${memory} -M \"${mac}\" -t ${vm_type} -T \"${timezone}\" -u ${user} -D ${domain} ${vm}"
        ${vm_manage} create \
            -c "${cpu}" \
            -d "${size}" \
            -m "${memory}" \
            -M "${mac}" \
            -t "${vm_type}" \
            -T "${timezone}" \
            -u "${user}" \
            -D "${domain}" \
            ${vm}
        if [[ "$?" != "0" ]]; then
            err "failed creating ${env_name}:${vm} with: ${vm_manage} create ${vm}"
            err "sudo ${vm_manage} create -M \"${mac}\" -c ${cpu} -d ${size} -m ${memory} -M \"${mac}\" -t ${vm_type} -T \"${timezone}\" -u ${user} -D ${domain} ${vm}"
        else
            good "${vm_manage} create -M \"${mac}\" -c ${cpu} -d ${size} -m ${memory} -M \"${mac}\" -t ${vm_type} -T \"${timezone}\" -u ${user} -D ${domain} ${vm}"
        fi
    else
        good "already have ${vm} at: ${KVM_VMS_DIR}/${vm}"
    fi
    (( vm_num++ ))
done

total_sleep=30
inf "${env_name} - sleeping for ${total_sleep} seconds"
slp ${total_sleep}

anmt "building vm network file for finding the new vms"
${vm_build_network_env}

good "done - building disks on ${env_name} kubernetes for vms=${vms} with fqdns=${nodes} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
