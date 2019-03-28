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
num_k8_nodes_expected=$(echo "${nodes}" | sed -e 's/ /\n/g' | wc -l)
base_image="${KVM_BASE_IMAGE_PATH}"
login_user="${LOGIN_USER}"
local_ssh_key="${LOCAL_SSH_KEY}"
local_ssh_key_pub="${LOCAL_SSH_KEY_PUB}"
pw_file="${K8_PASSWORD_FILE}"
ips="${K8_VM_IPS}"

if [[ "${BOOT_MODE}" == "building-base" ]]; then
    nodes="${KVM_BASE_NAME}"
    ips="${KVM_BASE_IP}"
fi

anmt "----------------------------------------------"
anmt "$(date) - ${env_name}:${BOOT_MODE} - installing ${login_user} ssh keys: ${local_ssh_key} and ${local_ssh_key_pub}"

if [[ ! -e ${local_ssh_key} ]]; then
    anmt "$(date) - ${env_name} - generating cluster ssh keys: ${local_ssh_key}"
    ssh-keygen -f ${local_ssh_key} -P ""
fi

anmt "$(date) - ${env_name} - cleaning up local ssh known_hosts for ips: ${ips}"
for ip in ${ips}; do
    ssh-keygen -f "~/.ssh/known_hosts" -R "${ip}" >> /dev/null 2>&1
done

anmt "$(date) - ${env_name} - cleaning up local ssh known_hosts for fqdns"
for ip in ${ips}; do
    ssh-keygen -f "~/.ssh/known_hosts" -R "${fqdns}" >> /dev/null 2>&1
done

if [[ ! -e ${pw_file} ]]; then
    anmt "$(date) - ${env_name} - creating password file for automating passwords: ${pw_file}"
    echo "${K8_VM_PASSWORD}" > ${pw_file}
    chmod 666 ${pw_file}
fi

num_nodes_online=0
num_checks=0
anmt "$(date) - ${env_name} - checking login to nodes: ${nodes}"
for fqdn in ${nodes}; do
    test_ssh=$(ssh -o StrictHostKeyChecking=no ${login_user}@${fqdn} "date" 2>&1)
    not_done=$(echo "${test_ssh}" | grep 'ssh: ' | wc -l)
    while [[ "${not_done}" != "0" ]]; do
        if [[ "${num_checks}" == "3" ]]; then
            inf "$(date) - waiting for ssh ${login_user}@${fqdn} login access for node=${num_nodes_online}/${num_k8_nodes_expected}"
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

anmt "$(date) - ${env_name} - installing keys with ssh-copy-id on fqdns: ${nodes}"
for fqdn in ${nodes}; do
    inf "$(date) - ${env_name} - installing on ${login_user}@${fqdn}: ssh-copy-id -i ~/.ssh/id_rsa.pub ${login_user}@${fqdn}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${login_user}@${fqdn} >> /dev/null 2>&1
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${fqdn} >> /dev/null 2>&1
done

anmt "$(date) - ${env_name} - installing keys with ssh-copy-id on ips: ${ips}"
for ip in ${ips}; do
    inf "$(date) - ${env_name} - installing on ${login_user}@${ip}: ssh-copy-id -i ~/.ssh/id_rsa.pub ${login_user}@${ip}"
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${login_user}@${ip} >> /dev/null 2>&1
    sshpass -f ${pw_file} ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub ${ip} >> /dev/null 2>&1
done

good "done - $(date) - ${env_name}:${BOOT_MODE} - installing ${login_user} ssh keys: ${local_ssh_key} and ${local_ssh_key_pub}"
anmt "----------------------------------------------"

exit 0
