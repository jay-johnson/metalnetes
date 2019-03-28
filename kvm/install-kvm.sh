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
os_type="${OS}"
password_file="${K8_PASSWORD_FILE}"

if [[ ! -e ${password_file} ]]; then
    anmt "$(date) - ${env_name} - creating password_file=${password_file}"
    echo "${K8_VM_PASSWORD}" > ${password_file}
fi

if [[ ! -e ${password_file} ]]; then
    err "$(date) - ${env_name} - missing password_file=${password_file}"
    exit 1
fi

user=${K8_VM_USER}
if [[ "${os_type}" == "ubu" ]]; then
    inf "$(date) - ${env_name} - anmt installing OS=${os_type} s3cmd, sshpass, kvm and arp-scan for finding vm ip addresses"
    apt install s3cmd sshpass qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager arp-scan
    nic_name=$(ifconfig | grep -E "enp|ens" | sed -e 's/:/ /g' | awk '{print $1}' | head -1)

    if [[ -e /etc/network/interfaces ]]; then
        test_exists=$(cat /etc/network/interfaces | grep br0 | wc -l)
        if [[ "${test_exists}" == "0" ]]; then
            echo "" >> /etc/network/interfaces
            echo "auto br0" >> /etc/network/interfaces
            echo "iface br0 inet dhcp" >> /etc/network/interfaces
            echo "      bridge_ports ${nic_name}" >> /etc/network/interfaces
            echo "      bridge_stp off" >> /etc/network/interfaces
            echo "      bridge_maxwait 0" >> /etc/network/interfaces
        fi
        anmt "adding user: ${user} to libvirt and libvirt-qemu"
        usermod -aG libvirt ${user}
        usermod -aG libvirt ${user}
    fi
    good "$(date) - ${env_name} - done installing kvm with support for bridge network adapters"
fi

exit 0
