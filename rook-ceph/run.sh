#!/bin/bash

cur_dir=$(pwd)
path_to_env="${cur_dir}/k8.env"
if [[ "${CLUSTER_CONFIG}" != "" ]]; then
    path_to_env="${CLUSTER_CONFIG}"
fi
if [[ ! -e ${path_to_env} ]]; then
    echo "failed to find env file: ${path_to_env} with CLUSTER_CONFIG=${CLUSTER_CONFIG}"
    exit 1
fi
source ${path_to_env}

env_name="${K8_ENV}"
use_path="${cur_dir}/rook-ceph"
secrets_path="${use_path}/secrets"
cert_env="dev"

anmt "----------------------------------------------"
anmt "deploying rook-ceph to ${env_name} with KUBECONFIG=${KUBECONFIG}"
inf ""

ceph_operator_file=${use_path}/operator.yaml
inf "creating ceph operator: ${ceph_operator_file}"
kubectl apply -f ${ceph_operator_file}
inf ""

anmt "Want to learn more about Rook and Ceph while you wait?"
anmt "- How the rook-ceph helm operator works: https://rook.io/docs/rook/master/helm-operator.html"
anmt "- How rook ceph volumes work: https://rook.io/docs/rook/master/ceph-quickstart.html"
inf ""

cur_date=$(date)
inf "${cur_date} - waiting for rook-ceph operator to enter the Running state"
num_sleeps=0
not_ready="0"
while [[ "${not_ready}" == "0" ]]; do
    test_rook_agent=$(kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-ceph-agent | awk '{print $3}' | grep -i running | wc -l)
    test_rook_op=$(kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-ceph-operator | awk '{print $3}' | grep -i running | wc -l)
    test_rook_disc=$(kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-discover | awk '{print $3}' | grep -i running | wc -l)
    if [[ "${test_rook_agent}" == "0" ]] || [[ "${test_rook_op}" == "0" ]] || [[ "${test_rook_disc}" == "0" ]]; then
        cur_date=$(date)
        let num_sleeps+=1
        modulus_sleep=$((${num_sleeps}%30))
        if [[ "${debug}" == "1" ]]; then
            inf "${cur_date} - still waiting on system pods sleep count: ${num_sleeps}"
        elif [[ "${modulus_sleep}" == "0" ]]; then
            inf "${cur_date} - still waiting on system pods"
            num_sleeps=0
        elif [[ $num_sleeps -gt 500 ]]; then
            inf ""
            err "Failed waiting for rook and ceph system pods to enter a valid Running state"
            inf ""
            ${use_path}/view-system-pods.sh
            echo "" >> /tmp/boot.log
            echo "rook ceph agent:" >> /tmp/boot.log
            kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-ceph-agent >> /tmp/boot.log
            echo "" >> /tmp/boot.log
            echo "rook ceph operator:" >> /tmp/boot.log
            kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-ceph-operator >> /tmp/boot.log
            echo "" >> /tmp/boot.log
            echo "rook ceph discover:" >> /tmp/boot.log
            kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-discover >> /tmp/boot.log
            echo "" >> /tmp/boot.log
            echo "rook ceph system pods:" >> /tmp/boot.log
            ${use_path}/view-system-pods.sh >> /tmp/boot.log
            inf ""
            exit 1 
        fi
        sleep 10
    else
        inf "${cur_date} - rook and ceph system pods are Running"
        not_ready=1
    fi
    anmt "$(date) checking pods:"
    test_rook_agent=$(kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-ceph-agent | awk '{print $3}' | grep -i running | wc -l)
    test_rook_op=$(kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-ceph-operator | awk '{print $3}' | grep -i running | wc -l)
    test_rook_disc=$(kubectl -n rook-ceph-system get pod --ignore-not-found | grep rook-discover | awk '{print $3}' | grep -i running | wc -l)
    kubectl -n rook-ceph-system get po | grep rook
    warn "- rook-ceph-operator (-n rook-ceph-system) found: ${test_rook_op}"
    warn "- rook-ceph-agent (-n rook-ceph-system) found: ${test_rook_agent}"
    warn "- rook-ceph-discover (-n rook-ceph-system) found: ${test_rook_disc}"
done

${use_path}/view-system-pods.sh

cluster_file=${use_path}/cluster.yaml
inf "creating cluster: ${cluster_file}"
kubectl apply -f ${cluster_file}
inf ""

cur_date=$(date)
inf "${cur_date} - waiting for rook-ceph cluster pods to enter the Running state"
num_sleeps=0
not_ready="0"
while [[ "${not_ready}" == "0" ]]; do
    test_ceph_mgr=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-mgr | awk '{print $3}' | grep -i running | wc -l)
    test_ceph_mon=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-mon | awk '{print $3}' | grep -i running | wc -l)
    test_ceph_osd=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-osd | awk '{print $3}' | grep -i running | wc -l)
    if [[ "${test_ceph_mgr}" == "0" ]] || [[ "${test_ceph_mon}" == "0" ]] || [[ "${test_ceph_osd}" == "0" ]]; then
        cur_date=$(date)
        let num_sleeps+=1
        modulus_sleep=$((${num_sleeps}%30))
        if [[ "${debug}" == "1" ]]; then
            inf "${cur_date} - still waiting on cluster pods sleep count: ${num_sleeps}"
        elif [[ "${modulus_sleep}" == "0" ]]; then
            inf "${cur_date} - still waiting on cluster pods"
            num_sleeps=0
        elif [[ $num_sleeps -gt 1200 ]]; then
            inf ""
            err "Failed waiting for rook and ceph pods to enter a valid Running state"
            inf ""
            ${use_path}/view-ceph-pods.sh
            inf ""
            exit 1 
        fi
        sleep 10
    else
        inf "${cur_date} - rook and ceph pods are Running"
        not_ready=1
    fi
    anmt "$(date) checking pods:"
    test_ceph_mgr=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-mgr | awk '{print $3}' | grep -i running | wc -l)
    test_ceph_mon=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-mon | awk '{print $3}' | grep -i running | wc -l)
    test_ceph_osd=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-osd | awk '{print $3}' | grep -i running | wc -l)
    kubectl -n rook-ceph get po | grep rook
    warn "- rook-ceph-mon (-n rook-ceph) found: ${test_ceph_mon}"
    warn "- rook-ceph-osd (-n rook-ceph) found: ${test_ceph_osd}"
    warn "- rook-ceph-mgr (-n rook-ceph) found: ${test_ceph_mgr}"
done

inf ""
${use_path}/show-pods.sh
inf ""

secret_namespace="rook-ceph"
storageclass_file=${use_path}/storageclass.yaml
inf "creating storage class: ${storageclass_file}"
kubectl apply -f ${storageclass_file}
inf ""

toolbox_file=${use_path}/toolbox.yaml
inf "create toolbox: ${toolbox_file}"
kubectl apply -f ${toolbox_file}
inf ""

cur_date=$(date)
inf "${cur_date} - waiting for rook toolbox to enter the Running state"
num_sleeps=0
not_ready="0"
while [[ "${not_ready}" == "0" ]]; do
    test_ceph_tools=$(kubectl -n rook-ceph get pod --ignore-not-found | grep rook-ceph-tools | awk '{print $3}' | grep -i running | wc -l)
    if [[ "${test_ceph_tools}" == "0" ]]; then
        cur_date=$(date)
        let num_sleeps+=1
        modulus_sleep=$((${num_sleeps}%30))
        if [[ "${debug}" == "1" ]]; then
            inf "${cur_date} - still waiting on rook-ceph-tools sleep count: ${num_sleeps}"
        elif [[ "${modulus_sleep}" == "0" ]]; then
            inf "${cur_date} - still waiting on rook-ceph-tools pods"
            num_sleeps=0
        elif [[ $num_sleeps -gt 1200 ]]; then
            inf ""
            err "Failed waiting for rook-ceph-tools pods to enter a valid Running state"
            inf ""
            ${use_path}/show-pods.sh
            inf ""
            exit 1 
        fi
        sleep 1
    else
        inf "${cur_date} - rook-ceph-tools pods are Running"
        not_ready=1
    fi
done

# ingress needed for dashboard
dashboard_enabled="0"
if [[ "${dashboard_enabled}" == "1" ]]; then
    ingress_file=${use_path}/ingress-${cert_env}.yaml
    inf "deploying ceph dashboard using service file: ${ingress_file}"
    kubectl apply -f ${ingress_file}
    inf ""
fi

good "done - deploying rook-ceph to ${env_name} with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
