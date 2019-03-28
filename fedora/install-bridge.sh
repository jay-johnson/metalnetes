#!/bin/bash

# This resolved networking issues on fedora 29: 

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
allow_query="${KVM_NAMED_ALLOW_QUERY_DNS_CIDR}"

anmt "-----------------------------------------------"
anmt "$(date) - ${env_name} - installing network ${K8_VM_NIC} with bridge device ${K8_VM_BRIDGE} dns ${K8_DOMAIN} with IP=${K8_DNS_SERVER_1} ALLOW_QUERY_DNS_CIDR=${allow_query}"

# install and set up
dnf -y install qemu-kvm libvirt virt-install bridge-utils
systemctl start libvirtd
systemctl enable libvirtd
nmcli connection del eno1
nmcli connection del ${K8_VM_BRIDGE}
nmcli connection add type bridge autoconnect yes con-name ${K8_VM_BRIDGE} ifname ${K8_VM_BRIDGE}
nmcli connection modify ${K8_VM_BRIDGE} ipv4.addresses ${K8_DNS_SERVER_1}/24 ipv4.method manual
nmcli connection modify ${K8_VM_BRIDGE} ipv4.gateway ${K8_GATEWAY}
nmcli connection modify ${K8_VM_BRIDGE} ipv4.dns ${K8_DNS_SERVER_1}
nmcli connection add type bridge-slave autoconnect yes con-name ${K8_VM_NIC} ifname eno1 master ${K8_VM_BRIDGE}

# https://gist.github.com/RLovelett/4a2fcaff2384826358f81ad16add49e3
test_exists=$(cat /etc/polkit-1/rules.d/80-libvirt-manage.rules | grep org.libvirt.unix.manage | grep subject.isInGroup | grep wheel | wc -l)
if [[ "${test_exists}" == "0" ]]; then
    cat > /etc/polkit-1/rules.d/80-libvirt-manage.rules <<EOF
    polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" && subject.local && subject.active && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
    });
EOF
fi
usermod --append --groups libvirt root
usermod --append --groups libvirt ${K8_VM_USER}
firewall-cmd --zone=trusted --change-interface ${K8_VM_BRIDGE} --permanent
firewall-cmd --add-port=5900/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=FedoraServer --list-ports

# https://superuser.com/questions/990855/configure-firewalld-to-allow-bridged-virtual-machine-network-access
firewall-cmd --permanent --direct --passthrough ipv4 -I FORWARD -i bridge0 -j ACCEPT
firewall-cmd --permanent --direct --passthrough ipv4 -I FORWARD -o bridge0 -j ACCEPT
firewall-cmd --reload

good "done - $(date) - ${env_name} - installing network ${K8_VM_NIC} with bridge device ${K8_VM_BRIDGE} dns ${K8_DOMAIN} with IP=${K8_DNS_SERVER_1} ALLOW_QUERY_DNS_CIDR=${allow_query}"
anmt "-----------------------------------------------"

exit 0
