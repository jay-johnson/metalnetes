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
tiller_rbac="${TILLER_RBAC}"
k8_ready=$(is_k8_ready)
tiller_running=$(kubectl get po -n kube-system | grep tiller-deploy | wc -l)

anmt "----------------------------------------"
anmt "deploying tiller rbac=${tiller_rbac} on ${env_name} - used by helm to control kubernetes using auth creds: KUBECONFIG=${KUBECONFIG}"
anmt "details on tiller: https://helm.sh/docs/using_helm/#easy-in-cluster-installation"
inf ""

# defined in CLUSTER_CONFIG file to exit if kubernetes is not running
stop_if_not_ready

if [[ "${tiller_running}" == "0" ]]; then
    anmt "creating service account for tiller in the kube-system"
    kubectl create serviceaccount --namespace kube-system tiller

    inf "creating rbac for tiller service account ${tiller_rbac}"
    kubectl apply -f ${tiller_rbac}

    inf "creating cluster role binding for tiller"
    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

    inf "patching any tiller deploys with the service account"
    kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

    anmt "initializing helm with tiller service account"
    helm init --upgrade --history-max 200 --service-account tiller

    inf "updating helm repo"
    helm repo update
else
    good "tiller already deployed"
fi

good "done - deploying helm locally for ${env_name} - helm will control kubernetes using auth creds: KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------"

exit 0
