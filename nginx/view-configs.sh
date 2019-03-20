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
namespace="default"
app_name="nginx"
pod_name=$(kubectl get pods -n ${namespace} | awk '{print $1}' | grep ${app_name} | head -1)

inf ""
anmt "-----------------------------------------"
good "${env_name} - getting the jupyter configuration: "
kubectl exec -it \
    ${pod_name} \
    -n ${namespace} \
    cat /etc/nginx/conf.d/ae-jupyter-ingress.conf

inf ""
anmt "-----------------------------------------"
good "${env_name} - getting the prometheus configuration: "
kubectl exec -it \
    ${pod_name} \
    -n ${namespace} \
    cat /etc/nginx/conf.d/ae-ae-prometheus-server.conf

inf ""
anmt "-----------------------------------------"
good "${env_name} - getting the minio configuration: "
kubectl exec -it \
    ${pod_name} \
    -n ${namespace} \
    cat /etc/nginx/conf.d/ae-ae-minio.conf

inf ""
anmt "-----------------------------------------"
good "${env_name} - getting the grafana configuration: "
kubectl exec -it \
    ${pod_name} \
    -n ${namespace} \
    cat /etc/nginx/conf.d/ae-ae-grafana.conf

exit 0
