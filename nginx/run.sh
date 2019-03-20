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

# install guide from
# https://github.com/nginxinc/kubernetes-ingress/blob/master/docs/installation.md#installing-the-ingress-controller

env_name="${K8_ENV}"
namespace="default"
use_path="$(dirname ${path_to_env})/nginx"

anmt "---------------------------------------------------------"
anmt "${env_name} - deploying nginx-ingress: https://github.com/nginxinc/kubernetes-ingress"

inf "${env_name} - building service account"
kubectl apply -f ${use_path}/ns-and-sa.yaml -n ${namespace}

inf "${env_name} - creating secrets"
kubectl apply -f ${use_path}/default-server-secret.yaml -n ${namespace}

inf "${env_name} - creating config map"
kubectl apply -f ${use_path}/nginx-config.yaml -n ${namespace}

inf "${env_name} - assigning rbac rules"
kubectl apply -f ${use_path}/rbac.yaml -n ${namespace}

# Deployment. Use a Deployment if you plan to dynamically change the number of Ingress controller replicas.
#
# DaemonSet. Use a DaemonSet for deploying the Ingress controller on every node or a subset of nodes.
# If you created a daemonset, ports 80 and 443 of the Ingress controller container are 
# mapped to the same ports of the node where the container is running. To access the
# Ingress controller, use those ports and an IP address of any node of the cluster
# where the Ingress controller is running.

inf "${env_name} - deploying as DaemonSet"
kubectl apply -f ${use_path}/nginx-ingress.yaml -n ${namespace}

inf "${env_name} - getting pods"
kubectl get pods -n ${namespace}

good "${env_name} - done deploying: nginx-ingress"
anmt "---------------------------------------------------------"

exit 0
