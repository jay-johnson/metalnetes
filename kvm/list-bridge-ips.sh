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

anmt "----------------------------------"
anmt "${env_name} - detecting all ips on ${bridge} with: sudo arp-scan -q -l --interface ${bridge}"
sudo arp-scan -q -l --interface ${bridge}
good "done - ${env_name} - detecting all ips on ${bridge} with: sudo arp-scan -q -l --interface ${bridge}"
anmt "----------------------------------"
