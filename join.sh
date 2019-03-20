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

initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
env_name="${K8_ENV}"
login_user="${LOGIN_USER}"
remote_tool_cluster_joiner="${REMOTE_TOOL_CLUSTER_JOINER}"
debug="${METAL_DEBUG}"
include_cluster_config="export CLUSTER_CONFIG=${k8_config_dir}/k8.env"

for i in "$@"
do
    contains_equal=$(echo ${i} | grep "=")
    if [[ "${i}" == "-d" ]]; then
        debug="1"
    fi
done

start_date=$(date)
anmt "---------------------------------------------------------"
anmt "${start_date} - joining kubernetes cluster ${env_name} to nodes: ${nodes}"
anmt "KUBECONFIG=${KUBECONFIG}"
inf ""

anmt "generating kubernetes cluster join command: ssh ${login_user}@${initial_master} 'kubeadm token create --print-join-command > ${remote_tool_cluster_joiner}'"
ssh ${login_user}@${initial_master} "${include_cluster_config}; kubeadm token create --print-join-command > ${remote_tool_cluster_joiner}"
inf ""

anmt "getting kubernetes cluster join command: ssh ${login_user}@${initial_master} 'cat ${remote_tool_cluster_joiner}'"
cluster_join_command=$(ssh ${login_user}@${initial_master} "cat ${remote_tool_cluster_joiner}")
inf " - join nodes with command: ${cluster_join_command}"
inf ""

for i in $secondary_nodes; do
    anmt "joining kubernetes cluster on ${i}: ssh ${login_user}@${i} '${include_cluster_config}; ${cluster_join_command}'"
    ssh ${login_user}@${i} "${include_cluster_config}; ${cluster_join_command}"
done
inf ""

anmt "waiting for cluster nodes to be ready: $(date -u +'%Y-%m-%d %H:%M:%S')"
not_done="1"
sleep_count=0
while [[ "${not_done}" == "1" ]]; do
    for i in ${nodes}; do
        cluster_status=$(ssh ${login_user}@${i} "${include_cluster_config}; kubectl get nodes -o wide --show-labels | grep NotReady | wc -l")
        if [[ "${cluster_status}" == "0" ]]; then
            good "cluster nodes are ready"
            not_done="0"
            break
        else
            sleep_count=$((sleep_count+1))
            if [[ ${sleep_count} -gt 30 ]]; then
                inf " - still waiting $(date -u +'%Y-%m-%d %H:%M:%S')"
                sleep_count=0
            fi
            sleep 1
        fi
    done
done
inf ""

end_date=$(date)
anmt "started on: ${start_date}"
anmt "ended on:   ${end_date}"
anmt "done - joining kubernetes cluster ${env_name} to nodes: ${nodes}"
anmt "---------------------------------------------------------"

if [[ "${debug}" == "1" ]]; then
    anmt "start using the cluster with:"
    echo ""
    echo "export KUBECONFIG=${KUBECONFIG}"
    echo "kubectl get nodes -o wide"
    echo ""
fi

exit 0
