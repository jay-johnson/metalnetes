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

# you can change these vars in the CLUSTER_CONFIG
env_name="${K8_ENV}"
nodes="${K8_NODES}"
vms="${K8_VMS}"
ips="${K8_VM_IPS}"
macs="${K8_VM_MACS}"
num_k8_nodes_expected=$(echo "${nodes}" | sed -e 's/ /\n/g' | wc -l)

use_path="$(dirname ${path_to_env})"
start_time="$(date)"
end_time=""

install_kvm_and_arp="${use_path}/kvm/install-kvm.sh"
start_vms="${use_path}/kvm/start-cluster-vms.sh"
find_vms_on_bridge="${use_path}/kvm/find-vms-on-bridge.sh"
bootstrap_vms="${use_path}/kvm/bootstrap-new-vms.sh"
setup_vms="${use_path}/install-centos-vms.sh"
start_tool="${use_path}/start.sh"

anmt "----------------------------------------"
anmt "booting new ${env_name} VMs with kubernetes cluster using CLUSTER_CONFIG=${CLUSTER_CONFIG} with KUBECONFIG=${KUBECONFIG}"
inf ""
anmt "VM names: ${vms} with shared profile"
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
inf "VM IP addresses: ${ips}"
inf "VM MAC addresses: ${macs}"
inf ""
anmt "deployment flags:"
inf "- start private docker registry: ${START_REGISTRY}"
inf "- start helm: ${START_HELM}"
inf "- start storage: ${START_STORAGE}"
inf "- start nginx ingress: ${START_INGRESS}"
inf "- start analysis engine: ${START_AE}"
inf "- start clean: ${START_CLEAN}"
inf "- install go: ${INSTALL_GO}"
inf "- install htop: ${INSTALL_HTOP}"
inf "- k8 node labels: ${K8_LABELS}"
inf ""
anmt "tools:"
inf "- install_kvm_and_arp=${install_kvm_and_arp}"
inf "- start_vms=${start_vms}"
inf "- find_vms_on_bridge=${find_vms_on_bridge}"
inf "- bootstrap_vms=${bootstrap_vms}"
inf "- setup_vms=${setup_vms}"
inf ""
warn "Logging in as root using sudo to reduce waiting for prompts"
inf ""

anmt "$(date) - ${env_name} - installing sshpass, kvm and arp"
sudo ${install_kvm_and_arp}
if [[ "$?" != "0" ]]; then
    err "failed to install kvm and components with: sudo ${install_kvm_and_arp}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - building and starting vms"
${start_vms}
if [[ "$?" != "0" ]]; then
    err "failed to start cluster vms with: ${start_vms}"
    exit 1
fi
inf ""

total_sleep=60
anmt "$(date) - ${env_name} - sleeping ${total_sleep} seconds before starting"
slp ${total_sleep}

anmt "$(date) - ${env_name} - building and starting vms"
${find_vms_on_bridge}
if [[ "$?" != "0" ]]; then
    err "failed to find vms on the bridge=${K8_VM_BRIDGE} with: ${find_vms_on_bridge}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - confirming vms with bootstap: ${bootstrap_vms}"
${bootstrap_vms}
if [[ "$?" != "0" ]]; then
    err "failed to bootstrap new vms with: ${bootstrap_vms}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - installing packages on vms: ${vms} using ${setup_vms}"
${setup_vms}
if [[ "$?" != "0" ]]; then
    err "failed to install and set up each vm with: ${setup_vms}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - starting kubernetes cluster across ${vms} on nodes ${nodes} with KUBECONFIG=${KUBECONFIG}"
${start_tool}
if [[ "$?" != "0" ]]; then
    err "failed starting ${env_name} kubernetes cluster across ${vms} on nodes ${nodes} with KUBECONFIG=${KUBECONFIG}"
    exit 1
fi
inf ""

end_time="$(date)"
anmt "started at:  ${start_time}"
anmt "finished at: ${end_time}"
good "done - booting new ${env_name} VMs with kubernetes cluster using CLUSTER_CONFIG=${CLUSTER_CONFIG} with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------"

inf ""
anmt "Start using your new cluster on ${vms} with nodes: ${nodes} with:"
inf ""
anmt "mkdir -p -m 775 $(dirname ${KUBECONFIG})"
anmt "scp ${login_user}@${K8_INITIAL_MASTER}:${KUBECONFIG} ${KUBECONFIG}"
anmt "export KUBECONFIG=${KUBECONFIG}"
inf ""
anmt "Add to your ~/.bashrc as an alias:"
inf ""
anmt "echo 'alias kdev=\"export KUBECONFIG=${KUBECONFIG}\"' >> ~/.bashrc"
inf ""

exit 0
