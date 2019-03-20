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

anmt "----------------------------------------------"
anmt "${env_name}:$(hostname) - installing cni"

if [[ ! -e /opt/cni/bin/ ]]; then
    mkdir -p -m 777 /tmp/cni
    cd /tmp/cni
    wget -q https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz
    if [[ "$?" != "0" ]]; then
        err "${env_name}:$(hostname) - failed downloading cni plugins with:"
        err "wget -q https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz"
        exit 1
    fi
    tar -zxf cni-plugins-amd64-v0.7.1.tgz
    mkdir -p -m 755 /opt/cni/bin >> /dev/null 2>&1
    move_files="bridge ipvlan macvlan sample vlan dhcp host-device portmap flannel host-local loopback ptp tuning"
    for m in ${move_files}; do
        mv ${m} /opt/cni/bin/ >> /dev/null 2>&1
    done
    rm -f cni-plugins-amd64-v0.7.1.tgz >> /dev/null 2>&1
    cd ${cur_dir}
    if [[ -e /tmp/cni ]]; then
        rm -rf /tmp/cni
    fi
    good "cni installed on $(hostname)"
else
    good "cni already installed on $(hostname)"
fi

good "done - ${env_name}:$(hostname) - installing cni"
anmt "----------------------------------------------"

exit 0
