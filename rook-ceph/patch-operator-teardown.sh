#!/bin/bash

# disabled for now
exit 0

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

anmt "----------------------------------------------"
anmt "$(date) - ${env_name} patching cephclusters.ceph.rook.io in case operator hangs KUBECONFIG=${KUBECONFIG}"
inf ""

# have seen this too where ceph pids cannot be stopped:
#
# root@m11:~# kill -9 17532
# root@m11:~# kill -9 14571
# root@m11:~# kill -9 19537
# root@m11:~# kill -9 $(ps auwwx | grep ceph | grep -v grep | awk '{print $2}')
# root@m11:~# ps auwwx | grep ceph | grep -v grep
# root     14571  0.0  0.0      0     0 ?        S<   22:59   0:00 [ceph-watch-noti]
# root     17532  0.0  0.0 123532   844 ?        D    22:59   0:00 /usr/bin/mount -t xfs -o rw,defaults /dev/rbd1 /var/lib/kubelet/plugins/ceph.rook.io/rook-ceph-system/mounts/pvc-9aaa30e5-535e-11e9-9fb8-0010019c9110
# root     19537  0.0  0.0      0     0 ?        S<   22:58   0:00 [ceph-msgr]
# root@m11:~#

# anmt "$(date) - ${env_name} sleeping to let the operator to delete cleanly without intervention"
# test_exists=$(kubectl get po -n rook-ceph-system | grep operator | wc -l)
# if [[ "${test_exists}" != "0" ]]; then
    # anmt "$(date) - ${env_name} sleeping again - detected operator after 5 seconds"
    # sleep 5
    # kubectl -n rook-ceph patch cephclusters.ceph.rook.io rook-ceph -p '{"metadata":{"finalizers": []}}' --type=merge
# fi

anmt "$(date) - ${env_name} patching cephclusters.ceph.rook.io in case operator hangs KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
