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

# PLEASE DO NOT CHANGE THIS LINE
# this file is scp-ed to the initial cluster master
# when kubeadm init runs it will create this file which
# is not the same one the CLUSTER_CONFIG uses by default
# that is source-d in the first few lines of this file
# also the k8.env is scp-ed along with this file to the
# configured K8_CONFIG_DIR
export KUBECONFIG=/etc/kubernetes/admin.conf

env_name="${K8_ENV}"

user_test=$(whoami)
if [[ "${user_test}" != "root" ]]; then
    err "please run as root"
    exit 1
fi

anmt "---------------------------------------------"
anmt "preparing ${env_name}:$(hostname) for running kubernetes on CentOS with KUBECONFIG=${KUBECONFIG}"

# automating install steps from:
# https://kubernetes.io/docs/setup/independent/install-kubeadm/

if [[ ! -e /etc/yum.repos.d/kubernetes.repo ]]; then
    inf "${env_name}:$(hostname) installing kubernetes repo"
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF
fi

anmt "${env_name}:$(hostname) turning off selinux with KUBECONFIG=${KUBECONFIG}"
setenforce 0
inf "${env_name}:$(hostname) installing kubernetes with KUBECONFIG=${KUBECONFIG}"
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
inf "${env_name}:$(hostname) installing kubernetes with KUBECONFIG=${KUBECONFIG}"
systemctl enable kubelet && systemctl start kubelet

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# need to still disable swap in: /etc/fstab
inf "${env_name}:$(hostname) - turning off swap - please ensure it is disabled in all entries in /etc/fstab with KUBECONFIG=${KUBECONFIG}"
swapoff -a

if [[ ! -e /etc/kubernetes ]]; then
    mkdir -p -m 755 /etc/kubernetes
fi

initial_node="${K8_INITIAL_MASTER}"
if [[ "$(hostname)" == "${initial_node}" ]]; then

    # for flannel to work must use the pod network cidr
    good "${env_name}:$(hostname) - initializing as a master kubernetes node with KUBECONFIG=${KUBECONFIG}"
    kubeadm init --pod-network-cidr=10.244.0.0/16
    inf ""

    inf "${env_name}:$(hostname) - allowing master to host containers with KUBECONFIG=${KUBECONFIG}"
    kubectl taint nodes --all node-role.kubernetes.io/master-
    if [[ "$?" != "0" ]]; then
        err "failed unlocking: ${env_name}:$(hostname) with: "
        err "kubectl taint nodes --all node-role.kubernetes.io/master-"
        exit 1
    fi
    inf ""

    good "done preparing ${env_name}:$(hostname) to run as a kubernetes master with KUBECONFIG=${KUBECONFIG}"
    inf ""

    if [[ ! -e $(dirname ${KUBECONFIG}) ]]; then
        mkdir -p -m 775 $(dirname ${KUBECONFIG})
    fi
    if [[ "${KUBECONFIG}" != "/etc/kubernetes/admin.conf" ]]; then
        cp /etc/kubernetes/admin.conf ${KUBECONFIG}
        chmod 666 ${KUBECONFIG}
    fi
    chmod 666 /etc/kubernetes/admin.conf
    good "done preparing ${env_name}:$(hostname) to run as a kubernetes master with KUBECONFIG=${KUBECONFIG}"
    inf ""
    good "sudo mkdir -p -m 775 $(dirname ${KUBECONFIG})"
    good "scp root@${initial_node}:${KUBECONFIG} ${KUBECONFIG}"
    good "export KUBECONFIG=${KUBECONFIG}"
    inf ""
else
    good "- $(hostname) - ready to join k8 initial_master=${initial_node}"
fi

anmt "---------------------------------------------"

exit 0
