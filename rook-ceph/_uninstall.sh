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
ceph_cleaner="${K8_CLEAN_CEPH}"

anmt "----------------------------------------------"
anmt "$(date) - ${env_name} - deleting rook-ceph on ${env_name} with KUBECONFIG=${KUBECONFIG}"
inf ""
warn "$(date) - ${env_name} - please follow the Rook Ceph Teardown guide if you hit issues:"
warn "https://github.com/rook/rook/blob/master/Documentation/ceph-teardown.md#cleaning-up-a-cluster"
inf ""

test_ceph_rook_namespace=$(kubectl get namespace | grep rook-ceph | wc -l)
if [[ "${test_ceph_rook_namespace}" != "0" ]]; then

    inf "$(date) - ${env_name} - deleting storageclass rook-ceph-block"
    kubectl delete storageclass rook-ceph-block
    inf ""

    inf "$(date) - ${env_name} - deleting storageclass rook-ceph-block"
    kubectl -n rook-ceph delete cephcluster rook-ceph
    inf ""

    num_sleeps=0
    not_done="$(kubectl -n rook-ceph get cephcluster | grep -v NAME | wc -l)"
    inf "$(date) - ${env_name} - starting wait for rook-ceph cluster to be deleted with KUBECONFIG=${KUBECONFIG}: kubectl -n rook-ceph delete cephcluster rook-ceph"
    while [[ "${not_done}" != "0" ]]; do
        sleep 1
        not_done="$(kubectl -n rook-ceph get cephcluster | grep -v NAME | wc -l)"
        if [[ "${num_sleeps}" == "5" ]]; then
            inf "$(date) - ${env_name} - waiting for rook-ceph cluster to be deleted with KUBECONFIG=${KUBECONFIG}: kubectl -n rook-ceph delete cephcluster rook-ceph"
            num_sleeps=0
        else
            (( num_sleeps++ ))
        fi
    done

    inf "$(date) - ${env_name} - done waiting for rook-ceph cluster to be deleted: ${not_done}"

    # disabled for now
    # anmt "$(date) - ${env_name} - starting backup ceph cleaner: ${ceph_cleaner}"
    # nohup ${ceph_cleaner} &

    anmt "$(date) - ${env_name} - deleting operator: kubectl delete --ignore-not-found -f ${use_path}/operator.yaml"
    kubectl delete --ignore-not-found -f ${use_path}/operator.yaml

    # disabled for now
    # anmt "$(date) - ${env_name} - sleeping in case: ${ceph_cleaner} has not finished"
    # ps auwwx | grep patch_operator_teardown
    # sleep 20
    # anmt "$(date) - ${env_name} - done sleeping for: ${ceph_cleaner}"

    ceph_mon_pod_name=$(kubectl -n rook-ceph get --ignore-not-found pod | grep rook-ceph-mon | awk '{print $1}')
    anmt "$(date) - ${env_name} - deleting ceph mon pod: ${ceph_mon_pod_name} found with: kubectl -n rook-ceph get --ignore-not-found pod | grep rook-ceph-mon | awk '{print \$1}'"
    if [[ "${ceph_mon_pod_name}" != "" ]]; then
        kubectl delete --ignore-not-found -n rook-ceph pod ${ceph_mon_pod_name}
    fi

    anmt "$(date) - ${env_name} - deleting service: kubectl delete --ignore-not-found objectstore -n rook-ceph rook-ceph-rgw-s3"
    kubectl delete --ignore-not-found service -n rook-ceph rook-ceph-rgw-s3

    anmt "$(date) - ${env_name} - deleting service: kubectl delete --ignore-not-found objectstore -n rook-ceph rook-ceph-rgw-s3-storage"
    kubectl delete --ignore-not-found service -n rook-ceph rook-ceph-rgw-s3-storage
fi

anmt "$(date) - ${env_name} - deleting ingress-dev: kubectl delete --ignore-not-found -f ${use_path}/ingress-dev.yaml"
kubectl delete --ignore-not-found -f ${use_path}/ingress-dev.yaml

anmt "$(date) - ${env_name} - deleting ingress-prod: kubectl delete --ignore-not-found -f ${use_path}/ingress-prod.yaml"
kubectl delete --ignore-not-found -f ${use_path}/ingress-prod.yaml

anmt "$(date) - ${env_name} - deleting toolbox: kubectl delete --ignore-not-found -f ${use_path}/toolbox.yaml"
kubectl delete --ignore-not-found -f ${use_path}/toolbox.yaml

anmt "$(date) - ${env_name} - deleting storageclass: kubectl delete --ignore-not-found -f ${use_path}/storageclass.yaml"
kubectl delete --ignore-not-found -f ${use_path}/storageclass.yaml

anmt "$(date) - ${env_name} - deleting cluster: kubectl delete --ignore-not-found -f ${use_path}/cluster.yaml"
kubectl delete --ignore-not-found -f ${use_path}/cluster.yaml

anmt "$(date) - ${env_name} - deleting cluster: kubectl -n rook-ceph delete --ignore-not-found cephcluster rook-ceph"
kubectl -n rook-ceph delete --ignore-not-found cephcluster rook-ceph

anmt "$(date) - ${env_name} - deleting namespaces: kubectl delete namespace rook-ceph rook-ceph-sysem"
kubectl delete namespace rook-ceph rook-ceph-sysem

anmt "$(date) - ${env_name} - ${env_name} cleaning up disks: ${disk_1_mount_path} ${disk_2_mount_path}"
for i in $nodes; do
    if [[ "${disk_1_mount_path}" != "" ]] && [[ "${disk_1_mount_path}" != "/" ]]; then
        anmt "$(date) - ${env_name}:${i} - deleting disk 1 dir: ${disk_1_mount_path}"
        ssh ${login_user}@${i} "rm -rf ${disk_1_mount_path}/*"
    fi
    if [[ "${disk_2_mount_path}" != "" ]] && [[ "${disk_2_mount_path}" != "/" ]]; then
        anmt "$(date) - ${env_name}:${i} - deleting disk 2 dir: ${disk_2_mount_path}"
        ssh ${login_user}@${i} "rm -rf ${disk_2_mount_path}/*"
    fi
done

good "$(date) - ${env_name} - done - deleting rook-ceph on ${env_name} with KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
