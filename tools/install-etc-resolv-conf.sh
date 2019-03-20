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

env_name="${K8_ENV}"
nodes="${K8_NODES}"
login_user="${LOGIN_USER}"
k8_config_dir="${K8_CONFIG_DIR}"
k8_dns_server_1="${K8_DNS_SERVER_1}"
k8_domain="${K8_DOMAIN}"

anmt "-----------------------------------------------"
anmt "${env_name}:$(hostname) - installing /etc/resolv.conf CentOS for running kubernetes in the ${env_name} cluster with DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"

anmt "setting /etc/resolv.conf with DNS_1=${k8_dns_server_1} DOMAIN=${k8_domain} nodes=${nodes}"
for node in ${nodes}; do
    command="systemctl disable NetworkManager.service && systemctl stop NetworkManager.service && echo \"search ${k8_domain}\" > /etc/resolv.conf && echo \"nameserver ${k8_dns_server_1}\" >> /etc/resolv.conf && echo \"nameserver 8.8.8.8\" >> /etc/resolv.conf && echo \"nameserver 8.8.4.4\" >> /etc/resolv.conf" #  && echo \"checking /etc/resolv.conf\"" && cat /etc/resolv.conf"
    anmt "- ${node} - installing /etc/resolv.conf with: ${login_user}@${node} \"${command}\""
    ssh ${login_user}@${node} "${command}"
done

good "done - ${env_name}:$(hostname) - installing /etc/resolv.conf CentOS for running kubernetes in the ${env_name} cluster with DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
anmt "-----------------------------------------------"
