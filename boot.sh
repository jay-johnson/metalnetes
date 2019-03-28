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
env_name="${K8_ENV}"
nodes="${K8_NODES}"
vms="${K8_VMS}"
ips="${K8_VM_IPS}"
macs="${K8_VM_MACS}"
login_user="${LOGIN_USER}"
num_k8_nodes_expected=$(echo "${nodes}" | sed -e 's/ /\n/g' | wc -l)

start_time="$(date)"
end_time=""

# assume current directory is the repo's base dir
kvm_base_image_path="${KVM_BASE_IMAGE_PATH}"
kvm_use_base_image="${KVM_USE_BASE_IMAGE}"
kvm_base_build_tool="${KVM_BASE_BUILD_TOOL}"
install_kvm_and_arp="${REPO_BASE_DIR}/kvm/install-kvm.sh"
start_vms="${REPO_BASE_DIR}/kvm/start-cluster-vms.sh"
find_vms_on_bridge="${REPO_BASE_DIR}/kvm/find-vms-on-bridge.sh"
bootstrap_vms="${REPO_BASE_DIR}/kvm/bootstrap-new-vms.sh"
setup_vms="${REPO_BASE_DIR}/install-centos-vms.sh"
start_tool="${REPO_BASE_DIR}/start.sh"

if [[ ! -e ${install_kvm_and_arp} ]]; then
    err "please run ./boot.sh from the base directory of the repository"
    err "currently in: $(pwd)"
    exit 1
fi

anmt "----------------------------------------"
anmt "$(date) - booting new ${env_name} VMs with kubernetes cluster using CLUSTER_CONFIG=${CLUSTER_CONFIG} with KUBECONFIG=${KUBECONFIG}"
inf ""
anmt "VM names: ${vms} with shared profile"
inf "- nodes: ${nodes}"
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

if [[ "${kvm_use_base_image}" == "1" ]]; then
    if [[ ! -e ${kvm_base_image_path} ]]; then
        anmt "$(date) - creating base vm: ${kvm_base_image_path} with builder=${kvm_base_build_tool} ip=${KVM_BASE_IP} mac=${KVM_BASE_MAC} fqdn=${KVM_BASE_NODE}"
        if [[ ! -e ${kvm_base_build_tool} ]]; then
            err "$(date) - failed creating base vm: ${kvm_base_image_path} missing the builder=${kvm_base_build_tool} file for creating a base vm with ip=${KVM_BASE_IP} mac=${KVM_BASE_MAC} fqdn=${KVM_BASE_NODE}"
            exit 1
        fi
        ${kvm_base_build_tool}
        if [[ "$?" != "0" ]]; then
            err "$(date) - failed creating base vm: ${kvm_base_image_path} with builder=${kvm_base_build_tool} ip=${KVM_BASE_IP} mac=${KVM_BASE_MAC} fqdn=${KVM_BASE_NODE}"
            exit 1
        fi
        good "$(date) - finished creating base vm: ${kvm_base_image_path} with builder: ${kvm_base_build_tool}"
        inf ""
    fi
fi

anmt "$(date) - ${env_name} - building and starting vms"
${start_vms}
if [[ "$?" != "0" ]]; then
    err "failed to start cluster vms with: ${start_vms}"
    exit 1
fi
inf ""

anmt "$(date) - ${env_name} - waiting for vms startup"
num_nodes_online=0
num_checks=0
inf "waiting for nodes to support ssh login: ${nodes}"
for fqdn in ${nodes}; do
    test_ssh=$(ssh -o StrictHostKeyChecking=no ${login_user}@${fqdn} "date" 2>&1)
    not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
    while [[ "${not_done}" != "0" ]]; do
        if [[ "${num_checks}" == "3" ]]; then
            inf "$(date) - sleeping before checking ${fqdn} supports ssh node=${num_nodes_online}/${num_k8_nodes_expected}"
            num_checks=0
        else
            (( num_checks++ ))
        fi
        sleep 10
        test_ssh=$(ssh -o StrictHostKeyChecking=no ${login_user}@${fqdn} "date" 2>&1)
        not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
    done
    (( num_nodes_online++ ))
done

anmt "$(date) - detected node=${num_nodes_online}/${num_k8_nodes_expected} online - finding vms"
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
anmt "echo 'alias k${env_name}=\"export KUBECONFIG=${KUBECONFIG}\"' >> ~/.bashrc"
inf ""

exit 0
