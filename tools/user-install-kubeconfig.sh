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

anmt "-------------------------"
anmt "${env_name}:$(hostname) - installing kubernetes config for user on to $HOME/.kube/config and ${KUBECONFIG}"

mkdir -p $HOME/.kube
if [[ -e $HOME/.kube/config ]]; then
    rm -f $HOME/.kube/config >> /dev/null 2>&1
fi

if [[ -e /etc/kubernetes/admin.conf ]]; then
    sudo chmod 666 /etc/kubernetes/admin.conf
fi

good "installing admin kubernetes config credentials using sudo"
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown $(id -u):$(id -g) $HOME/.kube/config
if [[ "${KUBECONFIG}" != "" ]]; then
    if [[ -e ${KUBECONFIG} ]]; then
        sudo chmod 666 ${KUBECONFIG}
    fi
    ls -lrt ${KUBECONFIG}
    sudo cp /etc/kubernetes/admin.conf ${KUBECONFIG} && sudo chown $(id -u):$(id -g) ${KUBECONFIG}
fi

inf "listing tokens:"
kubeadm token list

inf "listing pods:"
kubectl get pods

inf "listing nodes:"
kubectl get nodes

good "done - ${env_name}:$(hostname) - installing kubernetes config for user on to $HOME/.kube/config and ${KUBECONFIG}"
anmt "-------------------------"

exit 0
