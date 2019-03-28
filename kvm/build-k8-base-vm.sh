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

# you can change these vars in the CLUSTER_CONFIG
tools_dir="$(dirname ${path_to_env})"
ssh_key=""
nodes="${KVM_BASE_NODE}"
vm_name="${KVM_BASE_NAME}"
ip_address="${KVM_BASE_IP}"
mac="${KVM_BASE_MAC}"
env_name="${K8_ENV}"
cpu="${K8_VM_CPU}"
memory="${K8_VM_MEMORY}"
dns="${K8_DNS_SERVER_1}"
size="${K8_VM_SIZE}"
user="${K8_VM_USER}"
timezone="${K8_VM_TZ}"
domain="${K8_DOMAIN}"
bridge="${K8_VM_BRIDGE}"
login_user="${LOGIN_USER}"
vm_type="k8"
fqdn=$(echo "${nodes}" | awk '{print $1}')
vm_manage="${tools_dir}/kvm/vm-manage.sh"
vm_build_network_env="${tools_dir}/kvm/find-vms-on-bridge.sh"
image_base_dir=$(dirname ${KVM_BASE_IMAGE_PATH})
start_time="$(date)"
end_time=""

export BOOT_MODE="building-base"

# assume current directory is the repo's base dir
install_kvm_and_arp="${REPO_BASE_DIR}/kvm/install-kvm.sh"
find_vms_on_bridge="${REPO_BASE_DIR}/kvm/find-vms-on-bridge.sh"
bootstrap_vms="${REPO_BASE_DIR}/kvm/bootstrap-new-vms.sh"
setup_vm="${REPO_BASE_DIR}/centos/prepare-base-vm.sh"

if [[ ! -e ${install_kvm_and_arp} ]]; then
    err "please run ./build-k8-base-vm.sh from the base directory of the repository"
    err "currently in: $(pwd)"
    exit 1
fi

anmt "----------------------------------------"
anmt "$(date) - ${env_name}:${vm_name} - creating new base vm with CLUSTER_CONFIG=${CLUSTER_CONFIG}"
inf ""
anmt "VM names: ${vm_name} with shared profile"
inf "- cpu: ${K8_VM_CPU}"
inf "- memory: ${K8_VM_MEMORY} MB"
inf "- hardrive: ${K8_VM_SIZE} GB"
inf "- bridge: ${K8_VM_BRIDGE}"
inf "- dns: ${K8_DNS_SERVER_1}"
inf "- domain: ${K8_DOMAIN}"
inf "- user: ${K8_VM_USER} / ${K8_VM_PASSWORD}"
inf "- timezone: ${K8_VM_TZ}"
inf "- disk images dir: ${KVM_VMS_DIR}"
inf "- downloaded iso dir: ${KVM_IMAGES_DIR}"
inf "VM IP addresses: ${ip_address}"
inf "VM MAC addresses: ${mac}"
inf ""
anmt "tools:"
inf "- install_kvm_and_arp=${install_kvm_and_arp}"
inf "- find_vms_on_bridge=${find_vms_on_bridge}"
inf "- bootstrap_vms=${bootstrap_vms}"
inf "- setup_vm=${setup_vm}"
inf ""
warn "Logging in as root using sudo to reduce waiting for prompts"
inf ""

${vm_manage} remove ${KVM_BASE_NAME}   
if [[ -e ${image_base_dir} ]]; then
    rm -rf ${image_base_dir}/*
fi

anmt "$(date) - ${env_name} - installing sshpass, kvm and arp"
sudo ${install_kvm_and_arp}
if [[ "$?" != "0" ]]; then
    err "failed to install kvm and components with: sudo ${install_kvm_and_arp}"
    exit 1
fi
inf ""

if [[ -e "${HOME}/.ssh/known_hosts" ]]; then
    anmt "${env_name}:${vm_name} - removing any previous ssh known_hosts entries for ${ip_address} to prevent automation issues"
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${ip_address}" >> /dev/null 2>&1
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm_name}" >> /dev/null 2>&1
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm_name}.${domain}" >> /dev/null 2>&1
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${fqdn}" >> /dev/null 2>&1
    ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${login_user}@${fqdn}" >> /dev/null 2>&1
fi

anmt "$(date) - ${env_name} - building and starting vms: ${vm_manage}"
export IP="${ip_address}"
export MAC="${mac}"
export FQDN="${fqdn}"
export GATEWAY="${K8_GATEWAY}"
anmt "${env_name}:${vm_name} - creating ${vm_type} vm=${vm_num} with ${vm_manage}"
anmt "${vm_name} ${fqdn} ${size}G ${ip} ${mac} ${dns} bridge=${bridge}"
anmt "${vm_name} cpu=${cpu} memory=${memory} user=${user} ${domain}"
anmt "${vm_manage} create -c ${cpu} -d ${size} -m ${memory} -M \"${mac}\" -t ${vm_type} -T \"${timezone}\" -u ${user} -D ${domain} ${vm_name}"
${vm_manage} create \
    -c "${cpu}" \
    -d "${size}" \
    -m "${memory}" \
    -M "${mac}" \
    -t "${vm_type}" \
    -T "${timezone}" \
    -u "${user}" \
    -D "${domain}" \
    ${vm_name}
if [[ "$?" != "0" ]]; then
    err "failed creating ${env_name}:${vm_name} with: ${vm_manage} create ${vm_name}"
    err "${vm_manage} create -M \"${mac}\" -c ${cpu} -d ${size} -m ${memory} -M \"${mac}\" -t ${vm_type} -T \"${timezone}\" -u ${user} -D ${domain} ${vm_name}"
    exit 1
else
    good "${vm_manage} create -M \"${mac}\" -c ${cpu} -d ${size} -m ${memory} -M \"${mac}\" -t ${vm_type} -T \"${timezone}\" -u ${user} -D ${domain} ${vm_name}"
fi
inf ""

inf "waiting for nodes to support ssh login: ${nodes}"
for fqdn in ${nodes}; do
    test_ssh=$(ssh -o StrictHostKeyChecking=no ${login_user}@${fqdn} "date" 2>&1)
    not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
    cur_date=$(date)
    while [[ "${not_done}" != "0" ]]; do
        inf "${cur_date} - sleeping to let ${fqdn} start"
        sleep 10
        test_ssh=$(ssh -o StrictHostKeyChecking=no ${login_user}@${fqdn} "date" 2>&1)
        not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
        cur_date=$(date)
    done
done

export BOOT_MODE="building-base"
anmt "$(date) - ${env_name} - confirming vms with bootstap: ${bootstrap_vms}"
${bootstrap_vms}
if [[ "$?" != "0" ]]; then
    err "failed to bootstrap new vms with: ${bootstrap_vms}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - installing packages on vms: ${vm_name} using ${setup_vm}"
${setup_vm}
if [[ "$?" != "0" ]]; then
    err "failed to install and set up each vm with: ${setup_vm}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - shutting down ${vm_name}"
virsh shutdown ${vm_name} --mode acpi
if [[ "$?" != "0" ]]; then
    err "failed to shutdown ${vm_name} with: virsh shutdown ${vm_name} --mode acpi"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - sleeping to let the vm shutdown"
sleep 5

end_time="$(date)"
anmt "started at:  ${start_time}"
anmt "finished at: ${end_time}"
good "done - $(date) - ${env_name}:${vm_name} - creating new base vm with CLUSTER_CONFIG=${CLUSTER_CONFIG}"
anmt "----------------------------------------"

exit 0
