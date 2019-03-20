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

user_test=$(whoami)
if [[ "${user_test}" != "root" ]]; then
    err "please run as root"
    exit 1
fi

env_name="${K8_ENV}"

dir_to_check="/var/lib/cni/networks/cbr0"
anmt "-------------------------"
anmt "${env_name}:$(hostname) - cleaning up flannel and the cni"

cur_dir=$(pwd)
if [[ -e ${dir_to_check} ]]; then
    cd ${dir_to_check}
    for hash in $(tail -n +1 * | egrep '^[A-Za-z0-9]{64,64}$'); do
        if [ -z $(crictl pods --no-trunc | grep $hash | awk '{print $1}') ]; then
            grep -ilr $hash ./ | xargs rm
        fi;
    done
    cd ${cur_dir}
fi

# https://github.com/kubernetes/kubernetes/issues/39557#issuecomment-271944481
# and
# https://stackoverflow.com/questions/41359224/kubernetes-failed-to-setup-network-for-pod-after-executed-kubeadm-reset
anmt "${env_name}:$(hostname) - kubeadm reset -f"
kubeadm reset -f
anmt "${env_name}:$(hostname) - systemctl stop kubelet"
systemctl stop kubelet
anmt "${env_name}:$(hostname) - systemctl stop docker"
systemctl stop docker
anmt "${env_name}:$(hostname) - rm -rf /var/lib/cni/"
rm -rf /var/lib/cni/
anmt "${env_name}:$(hostname) - /var/lib/kubelet/*"
rm -rf /var/lib/kubelet/*
anmt "${env_name}:$(hostname) - /etc/cni/"
rm -rf /etc/cni/
anmt "${env_name}:$(hostname) - ifconfig cni0 down"
ifconfig cni0 down
anmt "${env_name}:$(hostname) - ip link delete cni0"
ip link delete cni0
anmt "${env_name}:$(hostname) - ifconfig flannel.1 down"
ifconfig flannel.1 down
anmt "${env_name}:$(hostname) - ip link delete flannel.1"
ip link delete flannel.1
anmt "${env_name}:$(hostname) - ifconfig docker0 down"
ifconfig docker0 down

anmt "${env_name}:$(hostname) - sleeping for 5 seconds"
sleep 5

anmt "${env_name}:$(hostname) - systemctl start docker"
systemctl start docker
anmt "${env_name}:$(hostname) - systemctl start kubelet"
systemctl start kubelet

good "done - ${env_name}:$(hostname) - cleaning up flannel and the cni"
anmt "-------------------------"

exit 0
