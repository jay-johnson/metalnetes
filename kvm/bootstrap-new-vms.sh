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

# this assumes the current user has root ssh access to the following hosts:
initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
ips="${K8_NODE_IPS}"
env_name="${K8_ENV}"
login_user="${LOGIN_USER}"
local_ssh_key="${LOCAL_SSH_KEY}"
local_ssh_key_pub="${LOCAL_SSH_KEY_PUB}"
vm_install_ssh_key_path="${K8_SSH_KEY}"
vm_install_ssh_key_pub_path="${K8_SSH_KEY_PUB}"
vm_network_installer="${REMOTE_VM_NETWORK_INSTALLER}"
k8_config_dir="${K8_CONFIG_DIR}"
k8_tools_dir="${K8_TOOLS_DIR}"
pw_file="${K8_PASSWORD_FILE}"
ssh_install_tool="${KVM_SSH_INSTALL_TOOL}"

anmt "------------------------------------"
anmt "$(date) - ${env_name}:${BOOT_MODE} - bootstrapping new vm with ssh keys and git and wget"

if [[ "${BOOT_MODE}" == "building-base" ]]; then
    nodes="${KVM_BASE_NAME}"
    ips="${KVM_BASE_IP}"
fi

if [[ "${cur_dir}" == ".." ]]; then
    local_ssh_key="../${LOCAL_SSH_KEY}"
    local_ssh_key_pub="../${LOCAL_SSH_KEY_PUB}"
fi

path_to_kvm="./kvm"
if [[ ! -e ${path_to_kvm} ]]; then
    path_to_kvm="."
fi
anmt "path to kvm: ${path_to_kvm}"

anmt "copying down virsh xmls for new vms"
for node in ${nodes}; do
    vm_name=$(echo ${node} | sed -e "s/\.${K8_DOMAIN}//g")
    anmt "${node} exporting xml for vm: ${vm_name}"
    vm_xml_dir="${path_to_kvm}/${vm_name}"
    if [[ ! -e ${vm_xml_dir} ]]; then
        mkdir -p -m 775 ${vm_xml_dir}
    fi
    vm_xml="${vm_xml_dir}/${vm_name}.xml"
    virsh dumpxml ${vm_name} > ${vm_xml}
done

anmt "$(date) - ${env_name} - installing ${login_user} ssh keys: ${ssh_install_tool}"
${ssh_install_tool}
if [[ "$?" != "0" ]]; then
    err "$(date) - ${env_name} - failed installing ${login_user} ssh keys: ${ssh_install_tool}"
    exit 1
fi

for node in ${nodes}; do
    anmt "${env_name}:${node} - creating directories: ${k8_config_dir} ${k8_tools_dir}"
    ssh -o StrictHostKeyChecking=no ${login_user}@${node} "chmod 775 /opt && mkdir -p -m 775 ${k8_config_dir} && mkdir -p -m 775 ${k8_tools_dir}"
    anmt "installing ${local_ssh_key} at ${node}:${vm_install_ssh_key_path}"
    scp -q ${local_ssh_key} ${login_user}@${node}:${vm_install_ssh_key_path}
    anmt "installing ${local_ssh_key_pub} at ${node}:${vm_install_ssh_key_pub_path}"
    scp -q ${local_ssh_key_pub} ${login_user}@${node}:${vm_install_ssh_key_pub_path}
    anmt "installing ${local_ssh_key} at ${node}:${install_key_on_vm}"
    scp -q ${local_ssh_key} ${login_user}@${node}:${vm_install_ssh_key_path}
    anmt "installing ${path_to_env} at ${node}:${k8_config_dir}/k8.env"
    scp -q ${path_to_env} ${login_user}@${node}:${k8_config_dir}/k8.env
    anmt "installing ${vm_network_installer} at ${node}:${k8_tools_dir}/install-network-device.sh"
    scp -q ${vm_network_installer} ${login_user}@${node}:${k8_tools_dir}/install-network-device.sh
    ssh -o StrictHostKeyChecking=no ${login_user}@${node} "systemctl enable rc-local && systemctl start rc-local"
    ssh -o StrictHostKeyChecking=no ${login_user}@${node} "chmod 777 ${k8_tools_dir}/install-network-device.sh && echo '#!/bin/bash' > /etc/rc.d/rc.local && echo ${k8_tools_dir}/install-network-device.sh >> /etc/rc.d/rc.local && chmod 777 /etc/rc.d/rc.local && echo '${k8_config_dir}/k8.env' > /opt/k8/use_env && touch /opt/k8/first-time-installer && chmod 666 /opt/k8/first-time-installer"
    anmt "installing keys on ${login_user}"
    ssh ${login_user}@${node} "mkdir -p -m 700 ~/.ssh && cp ${vm_install_ssh_key_path} ~/.ssh/id_rsa && cp ${vm_install_ssh_key_pub_path} ~/.ssh/id_rsa.pub && chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub && ls -lrt ~/.ssh/"
    anmt "------------"
done

for node in $nodes; do
    anmt "${env_name}:${node} - installing git and wget"
    inf "ssh ${login_user}@${node} \"yum install -y git wget uuidgen\""
    ssh ${login_user}@${node} "yum install -y git wget uuidgen"
    ssh ${login_user}@${node} "hostname ${node}"
    ssh ${login_user}@${node} "echo ${node} > /etc/hostname"
done

for node in $nodes; do
    vm_name=$(echo ${node} | sed -e "s/\.${K8_DOMAIN}//g")
    anmt "${env_name}:${node} - scp bashrc"
    scp -q ${path_to_kvm}/bashrc ${node}:~/.bashrc
    scp -q ${path_to_kvm}/bashrc ${login_user}@${node}:~/.bashrc
    anmt "${env_name}:${node} - scp vimrc"
    scp -q ${path_to_kvm}/vimrc ${node}:~/.vimrc
    scp -q ${path_to_kvm}/vimrc ${login_user}@${node}:~/.vimrc
done

anmt "${env_name} - installing /etc/docker/daemon.json"
for node in $nodes; do
    ssh ${login_user}@${node} "mkdir -p -m 755 /etc/docker"
    anmt "installing daemon.json with: scp -q ${path_to_kvm}/docker_daemon.json ${login_user}@${node}:/etc/docker/daemon.json"
    scp -q ${path_to_kvm}/docker_daemon.json ${login_user}@${node}:/etc/docker/daemon.json
    ssh ${login_user}@${node} "chmod 644 /etc/docker/daemon.json"
done

anmt "use these mac addresses with your router to ensure static ip addresses are preserved:"
for node in ${nodes}; do
    vm_name=$(echo ${node} | sed -e "s/\.${K8_DOMAIN}//g")
    mac_address=$(cat ${path_to_kvm}/${vm_name}/${vm_name}.xml | grep -i mac | grep -i address | sed -e "s/'/ /g" | awk '{print $3}')
    warn "${env_name}:${node} is on vm: ${vm_name} with MAC: ${mac_address}"
    echo "${mac_address}" > ${path_to_kvm}/${vm_name}/mac
done

anmt "${env_name} - installing bashrc and vimrc"
good "done - $(date) - ${env_name}:${BOOT_MODE} - bootstrapping new vm with ssh keys and git and wget"
anmt "------------------------------------"

exit 0
