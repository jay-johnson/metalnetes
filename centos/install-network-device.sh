#!/bin/bash

log=/tmp/fix-network
if [[ ! -e /opt/k8/first-time-installer ]]; then
    echo "$(date) - $(hostname) - already installed" > ${log}
    ifconfig -a >> ${log}
    exit 0
fi

log=/opt/k8/first-time-installed-network.log

path_to_env=""
if [[ -e /opt/k8/use_env ]]; then
    path_to_env=$(cat /opt/k8/use_env)
fi

if [[ "${path_to_env}" == "" ]]; then
    echo "$(date) - $(hostname) - did not detect an env file: ${path_to_env}"
    echo "$(date) - $(hostname) - did not detect an env file: ${path_to_env}" >> ${log}
    exit 1
fi
if [[ ! -e ${path_to_env} ]]; then
    echo "$(date) - $(hostname) - missing env file: ${path_to_env}"
    echo "$(date) - $(hostname) - missing env file: ${path_to_env}" >> ${log}
    exit 0
fi

echo "" > ${log}
$(date) >> ${log}
echo "$(date) - $(hostname) - path to env: ${path_to_env}" >> ${log}
source ${path_to_env}

env_name="${K8_ENV}"

ifconfig -a >> ${log}
if [[ ! -e ${path_to_env} ]]; then
    echo "$(date) - $(hostname) - Failed to find env file: ${path_to_env}" >> ${log}
else
    echo "$(date) - $(hostname) - loading env: ${path_to_env}"
fi

ips="${K8_VM_IP_1} ${K8_VM_IP_2} ${K8_VM_IP_3}"
macs=$(echo "${K8_VM_MAC_1} ${K8_VM_MAC_2} ${K8_VM_MAC_3}" | awk '{print tolower($0)}')

found_macs=$(ifconfig -a | grep ether | awk '{print $2}')
use_mac=""
use_ip=""
use_name=""
use_dns="${K8_DNS_SERVER_1}"
use_gateway="${K8_GATEWAY}"
for f in $found_macs; do
    for e in $macs; do
        if [[ "${f}" == "${e}" ]]; then
            echo "$(date) - $(hostname) found mac: ${e}" >> $log
            use_mac="${e}"
            if [[ "${K8_VM_MAC_1}" == "${use_mac}" ]]; then
                use_name=$(echo "${K8_NODES}" | awk '{print $1}')
                use_ip="${K8_VM_IP_1}"
            elif [[ "${K8_VM_MAC_2}" == "${use_mac}" ]]; then
                use_name=$(echo "${K8_NODES}" | awk '{print $2}')
                use_ip="${K8_VM_IP_2}"
            elif [[ "${K8_VM_MAC_3}" == "${use_mac}" ]]; then
                use_name=$(echo "${K8_NODES}" | awk '{print $3}')
                use_ip="${K8_VM_IP_3}"
            fi
            break
        fi
    done
    if [[ "${use_mac}" != "" ]]; then
        echo "$(date) - $(hostname) - name=${use_name} ip=${use_ip} mac=${use_mac}"
        echo "$(date) - $(hostname) - name=${use_name} ip=${use_ip} mac=${use_mac}" >> $log
        break
    fi
done

if [[ "${use_mac}" == "" ]]; then
    echo "$(date) - $(hostname) - did not find networking for: name=${use_name} ip=${use_ip} mac=${use_mac}" >> $log
    exit 0
fi

echo "$(date) - $(hostname) - name=${use_name} ip=${use_ip} mac=${use_mac}" >> $log

echo "$(date) - $(hostname) - unlocking /etc/sysconfig/network-scripts/ifcfg-eth0" >> $log
chattr -i /etc/sysconfig/network-scripts/ifcfg-eth0

cat <<EOF | tee /etc/sysconfig/network-scripts/ifcfg-eth0
NAME=eth0
DEVICE=eth0
IPADDR=${use_ip}
GATEWAY=${use_gateway}
DNS1=${use_dns}
HWADDR=${use_mac}
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
ONBOOT=yes
PREFIX=24
DNS2=8.8.8.8
DNS3=8.8.4.4
IPV6_PRIVACY=no
ZONE=public
EOF

echo "$(date) - $(hostname) - locking /etc/sysconfig/network-scripts/ifcfg-eth0" >> $log
chattr +i /etc/sysconfig/network-scripts/ifcfg-eth0

if [[ -e /opt/k8/first-time-installer ]]; then
    rm -f /opt/k8/first-time-installer
fi

echo "$(date) - $(hostname) - setting hostname: ${use_name}" >> $log
hostname ${use_name} >> $log 2>&1
echo "${use_name}" > /etc/hostname

echo "$(date) - $(hostname) - name=${use_name} ip=${use_ip} mac=${use_mac}" >> $log
cat /etc/sysconfig/network-scripts/ifcfg-eth0 >> $log

echo "$(date) - $(hostname) - restarting eth0" >> $log
ifdown eth0 >> $log 2>&1
ifup eth0 >> $log 2>&1

echo "$(date) - $(hostname) - checking network" >> $log
ifconfig -a >> $log

chmod 666 ${log}

echo "$(date) - $(hostname) - rebooting" >> $log
reboot

exit 0
