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

initial_master="${K8_INITIAL_MASTER}"
secondary_nodes="${K8_SECONDARY_MASTERS}"
nodes="${initial_master} ${secondary_nodes}"
login_user="${LOGIN_USER}"
env_name="${K8_ENV}"
use_path="${cur_dir}/rook-ceph"
secrets_path="${use_path}/secrets"
cert_env="dev"
disk_1_mount_path="${VM_DISK_1_MOUNT_PATH}"
disk_2_mount_path="${VM_DISK_2_MOUNT_PATH}"
storage_type="${STORAGE_TYPE}"

anmt "----------------------------------------------"
anmt "deleting rook-ceph on ${env_name} with KUBECONFIG=${KUBECONFIG}"
inf ""

test_ceph_rook_namespace=$(kubectl get namespace | grep rook-ceph | wc -l)
if [[ "${test_ceph_rook_namespace}" != "0" ]]; then
    inf "deleting pool and replicapool: kubectl delete --ignore-not-found -n rook-ceph pool replicapool"
    kubectl delete --ignore-not-found -n rook-ceph pool replicapool
    inf ""

    ceph_mon_pod_name=$(kubectl -n rook-ceph get --ignore-not-found pod | grep rook-ceph-mon | awk '{print $1}')
    anmt "deleting ceph mon pod: ${ceph_mon_pod_name} found with: kubectl -n rook-ceph get --ignore-not-found pod | grep rook-ceph-mon | awk '{print \$1}'"
    if [[ "${ceph_mon_pod_name}" != "" ]]; then
        kubectl delete --ignore-not-found -n rook-ceph pod ${ceph_mon_pod_name}
    fi

    anmt "deleting service: kubectl delete --ignore-not-found objectstore -n rook-ceph rook-ceph-rgw-s3"
    kubectl delete --ignore-not-found service -n rook-ceph rook-ceph-rgw-s3

    anmt "deleting service: kubectl delete --ignore-not-found objectstore -n rook-ceph rook-ceph-rgw-s3-storage"
    kubectl delete --ignore-not-found service -n rook-ceph rook-ceph-rgw-s3-storage
fi

anmt "deleting ingress-dev: kubectl delete --ignore-not-found -f ${use_path}/ingress-dev.yaml"
kubectl delete --ignore-not-found -f ${use_path}/ingress-dev.yaml

anmt "deleting ingress-prod: kubectl delete --ignore-not-found -f ${use_path}/ingress-prod.yaml"
kubectl delete --ignore-not-found -f ${use_path}/ingress-prod.yaml

anmt "deleting toolbox: kubectl delete --ignore-not-found -f ${use_path}/toolbox.yaml"
kubectl delete --ignore-not-found -f ${use_path}/toolbox.yaml

anmt "deleting storageclass: kubectl delete --ignore-not-found -f ${use_path}/storageclass.yaml"
kubectl delete --ignore-not-found -f ${use_path}/storageclass.yaml

anmt "deleting cluster: kubectl delete --ignore-not-found -f ${use_path}/cluster.yaml"
kubectl delete --ignore-not-found -f ${use_path}/cluster.yaml

anmt "deleting operator: kubectl delete --ignore-not-found -f ${use_path}/operator.yaml"
kubectl delete --ignore-not-found -f ${use_path}/operator.yaml

anmt "${env_name} cleaning up disks: ${disk_1_mount_path} ${disk_2_mount_path}"
for i in $nodes; do
    if [[ "${disk_1_mount_path}" != "" ]] && [[ "${disk_1_mount_path}" != "/" ]]; then
        anmt "- ${env_name}:${i} - deleting disk 1 dir: ${disk_1_mount_path}"
        ssh ${login_user}@${i} "rm -rf ${disk_1_mount_path}/* >> /dev/null 2>&1"
    fi
    if [[ "${disk_2_mount_path}" != "" ]] && [[ "${disk_2_mount_path}" != "/" ]]; then
        anmt "- ${env_name}:${i} - deleting disk 2 dir: ${disk_2_mount_path}"
        ssh ${login_user}@${i} "rm -rf ${disk_2_mount_path}/* >> /dev/null 2>&1"
    fi
done

good "done - deleting rook-ceph on ${env_name} with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
