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

user=${K8_VM_USER}
inf "anmt installing kvm and arp-scan for finding vm ip addresses"
apt install sshpass qemu-kvm libvirt-clients libvirt-daemon-system bridge-utils virt-manager arp-scan

nic_name=$(ifconfig | grep -E "enp|ens" | sed -e 's/:/ /g' | awk '{print $1}' | head -1)

echo "" >> /etc/network/interfaces
echo "auto br0" >> /etc/network/interfaces
echo "iface br0 inet dhcp" >> /etc/network/interfaces
echo "      bridge_ports ${nic_name}" >> /etc/network/interfaces
echo "      bridge_stp off" >> /etc/network/interfaces
echo "      bridge_maxwait 0" >> /etc/network/interfaces

anmt "adding user: ${user} to libvirt and libvirt-qemu"
adduser ${user} libvirt
adduser ${user} libvirt-qemu

good "done installing kvm with support for bridge network adapters"

exit 0