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
k8_config_dir="${K8_CONFIG_DIR}"
k8_tools_dir="${K8_TOOLS_DIR}"
pw_file="${K8_PASSWORD_FILE}"

if [[ "${cur_dir}" == ".." ]]; then
    local_ssh_key="../${LOCAL_SSH_KEY}"
    local_ssh_key_pub="../${LOCAL_SSH_KEY_PUB}"
fi

anmt "------------------------------------"
anmt "${env_name} - bootstrapping new vm with ssh keys and git and wget"

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
    inf "virsh dumpxml ${vm_name} > ${vm_xml}"
    virsh dumpxml ${vm_name} > ${vm_xml}
done

anmt "cleaning up known_hosts"
for ip in ${ips}; do
    ssh-keygen -f "~/.ssh/known_hosts" -R "${ip}"
done

for node in ${nodes}; do
    ssh-keygen -f "~/.ssh/known_hosts" -R "${node}"
done

anmt "creating password file for automating passwords: ${pw_file}"
echo "${K8_VM_PASSWORD}" > ${pw_file}

anmt "ssh-copy-id keys"
for ip in ${ips}; do
    anmt "installing on ${login_user}@${ip}: ssh-copy-id -i ~/.ssh/id_rsa.pub ${login_user}@${ip}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${login_user}@${ip}
    anmt "installing on ${ip}: ssh-copy-id -i ~/.ssh/id_rsa.pub ${ip}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${ip}
done

for node in ${nodes}; do
    anmt "installing on ${login_user}@${node}: ssh-copy-id -i ~/.ssh/id_rsa.pub ${login_user}@${node}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${login_user}@${node}
    anmt "installing on ${node}: ssh-copy-id -i ~/.ssh/id_rsa.pub ${node}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${node}
done

anmt "installing ${login_user} ssh keys: ${local_ssh_key} and ${local_ssh_key_pub} on vms: ${vm_install_ssh_key_path}"

if [[ ! -e ${local_ssh_key} ]]; then
    anmt "generating ssh keys for cluster nodes"
    ssh-keygen -f ${local_ssh_key} -P ""
fi

for node in ${nodes}; do
    anmt "installing on ${login_user}@{node}: ssh-copy-id -i ${local_ssh_key_pub} ${login_user}@${node}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ${local_ssh_key_pub} ${login_user}@${node}
    anmt "installing on ${node}: ssh-copy-id -i ${local_ssh_key_pub} ${node}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ${local_ssh_key_pub} ${node}
    anmt "${env_name}:${node} - creating directories: ${k8_config_dir} ${k8_tools_dir}"
    ssh -o StrictHostKeyChecking=no ${login_user}@${node} "chmod 775 /opt && mkdir -p -m 775 ${k8_config_dir} && mkdir -p -m 775 ${k8_tools_dir}"
    anmt "installing ${local_ssh_key} at ${node}:${vm_install_ssh_key_path}"
    scp -q ${local_ssh_key} ${login_user}@${node}:${vm_install_ssh_key_path}
    anmt "installing ${local_ssh_key_pub} at ${node}:${vm_install_ssh_key_pub_path}"
    scp -q ${local_ssh_key_pub} ${login_user}@${node}:${vm_install_ssh_key_pub_path}
    anmt "installing ${local_ssh_key} at ${node}:${install_key_on_vm}"
    scp -q ${local_ssh_key} ${login_user}@${node}:${vm_install_ssh_key_path}
    anmt "installing keys on ${login_user}"
    ssh ${login_user}@${node} "mkdir -p -m 700 ~/.ssh && cp ${vm_install_ssh_key_path} ~/.ssh/id_rsa && cp ${vm_install_ssh_key_pub_path} ~/.ssh/id_rsa.pub && chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub && ls -lrt ~/.ssh/"
    anmt "------------"
done

for node in $nodes; do
    anmt "${env_name}:${node} - installing git and wget"
    inf "ssh ${login_user}@${node} \"yum install -y git wget\""
    ssh ${login_user}@${node} "yum install -y git wget"
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
good "done - ${env_name} - installing ssh keys and initial bootstrap rpms"
anmt "------------------------------------"

exit 0
