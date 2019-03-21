#!/bin/bash

# show dates on all logs
export USE_SHOW_DATES=1

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

namespace="ae"
ae_deploy_dir="${AE_DEPLOY_DIR}"
env_name="${K8_ENV}"

if [[ "${1}" != "" ]]; then
    ae_deploy_dir=${1}
fi

storage_type="${STORAGE_TYPE}"
redis="${ae_deploy_dir}/redis/values.yaml"
minio="${ae_deploy_dir}/minio/values.yaml"
ae="${ae_deploy_dir}/ae/values.yaml"
jupyter="${ae_deploy_dir}/ae-jupyter/values.yaml"
set_storage="${ae_deploy_dir}/set-storage-class.sh"
build_helm_charts="${ae_deploy_dir}/build.sh"
ae_job_runner="${ae_deploy_dir}/cron/run-job.sh"
ae_job_restore_logs="${ae_deploy_dir}/logs-job-restore.sh"
ae_describe_engine="${ae_deploy_dir}/describe-engine.sh"
ae_logs_engine="${ae_deploy_dir}/logs-engine.sh"
ae_install_tls_secret="${ae_deploy_dir}/install-tls.sh"
ae_view_ticker_data_in_redis="${ae_deploy_dir}/view-ticker-data-in-redis.sh"
ae_monitor_start="${ae_deploy_dir}/monitor-start.sh"

if [[ ! -e ${ae} ]]; then
    cd ${ae_deploy_dir}
    if [[ ! -e ${ae} ]]; then
        err "${env_name} - unable to find path to ae core in deploy_dir=${ae_deploy_dir} with helm values file: ${ae}"
        exit 1
    fi
fi

anmt "--------------------------------"
anmt "${env_name} - build helm charts=${build_helm_charts} then starting with helm: ae=${ae} redis=${redis} minio=${minio} KUBECONFIG=${KUBECONFIG}"

test_kubectl=$(which kubectl | wc -l)
if [[ "${test_kubectl}" == "0" ]]; then
    err "Failed to find kubectl on the supported PATH environment variable - please install kubectl and export the PATH for the cron job to work"
    cd ${cur_dir}
    exit 1
fi

test_helm=$(which helm | wc -l)
if [[ "${test_helm}" == "0" ]]; then
    err "Failed to find helm on the supported PATH environment variable - please install helm and export the PATH for the cron job to work"
    echo "there is an installer in the repo's root directory:"
    echo "./deploy-helm.sh"
    cd ${cur_dir}
    exit 1
fi

anmt "using ae from dir ${ae_deploy_dir} KUBECONFIG=${KUBECONFIG}"

anmt "getting kubernetes nodes:"
kubectl get nodes -o wide

anmt "getting kubernetes default pods:"
kubectl get pods

anmt "checking for namespace: ${namespace}"
test_ns=$(kubectl get --ignore-not-found namespace ae | wc -l)
if [[ "${test_ns}" == "0" ]]; then
    kubectl create namespace ${namespace}
fi

anmt "getting kubernetes ae pods:"
kubectl get pods -n ${namespace}

# anmt "installing docker registry secret"
# ./install-registry-secret.sh

# anmt "installing ceph secret"
# ./install-ceph-secret.sh

anmt "${env_name} - setting ${storage_type} as default storageClass"
${set_storage} ${storage_type}
if [[ "$?" != "0" ]]; then
    err "${env_name} - failed setting default storageClass to: ${storage_type} with commant: ${set_storage} ${storage_type}"
    cd ${cur_dir}
    exit 1
fi

anmt "${env_name} - building charts: ${build_helm_charts}"
cd $(dirname ${build_helm_charts})
${build_helm_charts}
if [[ "$?" != "0" ]]; then
    err "${env_name} - failed setting building charts with: ${build_helm_charts}"
    cd ${cur_dir}
    exit 1
fi

test_running=$(helm ls | grep ae | grep -v -E "ae-backup|ae-intraday|ae-daily|ae-weekly|ae-jupyter|ae-redis|ae-minio|ae-grafana|ae-prometheus" | wc -l)
if [[ "${test_running}" == "0" ]]; then
    # install ae first to get the secrets for minio and redis
    anmt "${env_name} - installing ae"
    good "${env_name} - helm install --name=ae ./ae --namespace=${namespace} -f ${ae}"
    helm install \
        --name=ae \
        ./ae \
        --namespace=${namespace} \
        -f ${ae}
    if [[ "$?" != "0" ]]; then
        err "${env_name} - failed starting ae with values: ${ae}"
        cd ${cur_dir}
        exit 1
    fi
else
    good "${env_name} - ae core is already running"
fi

test_minio=$(helm ls | grep ae-minio | wc -l)
if [[ "${test_minio}" == "0" ]]; then
    test_minio_tls=$(kubectl get --ignore-not-found -n ${namespace} secret | grep tls.minio | wc -l)
    if [[ "${test_minio_tls}" == "0" ]]; then
        anmt "${env_name} - installing minio secret: tls.minio"
        ./install-tls.sh tls.minio ./minio/ssl/aeminio_server_key.pem ./minio/ssl/aeminio_server_cert.pem
    else
        good "${env_name} - tls secret: tls.minio already exists"
    fi
    anmt "${env_name} - installing minio"
    good "${env_name} - helm install --name=ae-minio local/minio --namespace=${namespace} -f ${minio}"
    helm install \
        --name=ae-minio \
        local/minio \
        --namespace=${namespace} \
        -f ${minio}
    if [[ "$?" != "0" ]]; then
        err "${env_name} - failed starting minio with values: ${minio}"
        cd ${cur_dir}
        exit 1
    fi
else
    good "${env_name} - minio is already installed"
fi

test_redis=$(helm ls | grep ae-redis | wc -l)
if [[ "${test_redis}" == "0" ]]; then
    anmt "${env_name} - installing redis"
    good "${env_name} - helm install --name=ae-redis stable/redis --namespace=${namespace} -f ${redis}"
    helm install \
        --name=ae-redis \
        stable/redis \
        --namespace=${namespace} \
        -f ${redis}
    if [[ "$?" != "0" ]]; then
        err "${env_name} - failed starting redis with values: ${redis}"
        cd ${cur_dir}
        exit 1
    fi
else
    good "redis is already installed"
fi

test_jupyter=$(helm ls | grep ae-jupyter | wc -l)
if [[ "${test_jupyter}" == "0" ]]; then
    anmt "${env_name} - installing jupyter"
    good "${env_name} - helm install --name=ae-jupyter ./ae-jupyter --namespace=${namespace} -f ${jupyter}"
    helm install \
        --name=ae-jupyter \
        ./ae-jupyter \
        --namespace=${namespace} \
        -f ${jupyter}
    if [[ "$?" != "0" ]]; then
        err "${env_name} - failed starting jupyter with values: ${redis}"
        cd ${cur_dir}
        exit 1
    fi
else
    good "jupyter is already installed"
fi
echo ""

anmt "${env_name} - checking running charts:"
helm ls

anmt "${env_name} - getting pods in ae namespace before starting sleeps:"
kubectl get pods -n ae

max_sleep_cycles=30
sleep_seconds_per_cycle=30
total_cycle_sleeps=0
not_done=1
already_running=$(kubectl get pods -n ae | grep -i -E "running|completed" | grep -v NAME | wc -l)
if [[ "${already_running}" -gt 5 ]]; then
    not_done=0
fi
while [[ "${not_done}" == "1" ]]; do
    anmt "$(date) - ${env_name} - sleeping for ${sleep_seconds_per_cycle} more seconds before checking ae pods"
    sleep ${sleep_seconds_per_cycle}
    still_downloading=$(kubectl get pods -n ae | grep -i -E "init|containercreating" | grep -v NAME | wc -l)
    if [[ "${still_downloading}" != "0" ]]; then
        echo "$(date) - ${env_name} - still waiting for pods to download and start: "
        kubectl get pods -n ae
        inf ""
        (( total_cycle_sleeps++ ))
        if [[ ${total_cycle_sleeps} -gt ${max_sleep_cycles} ]]; then
            err "$(date) - ${env_name} - failed to download ae pods in a timely manner after waiting (${max_sleep_cycles} * ${sleep_seconds_per_cycle}) - stopping for now - total_cycles=${total_cycle_sleeps} > max=${max_sleep_cycles}"
            exit 1
        fi
    else
        found_issues=$(kubectl get pods -n ae | grep -vi -E "running|completed" | grep -v NAME | wc -l)
        if [[ "${found_issues}" != "0" ]]; then
            warn "$(date) - ${env_name} - detected possible deployment issue - please review this error to take corrective action or see if it cleans up automatically:"
            kubectl get pods -n ae 
            warn "$(date) - ${env_name} - please note: while this is in active development it is easier to uninstall then reinstall if the problem continues with:"
            err "repo_base/ae/_uninstall.sh"
            warn "if you are ok with deleting the redis data you need to manually delete it with:"
            err "kubectl delete -n ae pvc redis-data-ae-redis-master-0"
            warn "then start the cluster with:"
            err "repo_base/deploy-ae.sh"
            inf ""
        else
            not_done="0"
        fi
    fi
done

anmt "${env_name} - checking for pod errors"
found_error=$(kubectl get pods -n ae | grep -vi -E "running|completed" | grep -v NAME | wc -l)
if [[ "${found_error}" != "0" ]]; then
    err "failed to start ae pods:"
    kubectl get pods -n ae
    exit 1
else
    good "${env_name} - ae pods done ContainerCreating and no detected errors"
    kubectl get pods -n ae
fi

if [[ "${AE_RESTORE_ON_STARTUP}" == "1" ]]; then
    anmt "${env_name} - restoring latest pricing data from S3 to Redis with helm ae-restore chart: ${ae_job_runner} restore ${KUBECONFIG} ${ae_deploy_dir}"
    ${ae_job_runner} restore ${KUBECONFIG} ${ae_deploy_dir}
    if [[ "$?" != "0" ]]; then
        err "${env_name} - failed running job: restore ${KUBECONFIG} ${ae_deploy_dir}"
        cd ${cur_dir}
        exit 1
    fi

    anmt "sleeping for 10 seconds before checking ae-restore job"
    sleep 10

    anmt "${env_name} - checking restore logs:"
    ${ae_job_restore_logs}
fi

anmt "${env_name} - getting kubernetes ae pods:"
kubectl get pods -n ${namespace}

anmt "${env_name} - checking engine pod:"
${ae_describe_engine}
${ae_logs_engine}

anmt "${env_name} - installing tls secrets: ${ae_install_tls_secret}"
${ae_install_tls_secret} tls.aeminio ./minio/ssl/aeminio_server_key.pem ./minio/ssl/aeminio_server_cert.pem ${namespace}
${ae_install_tls_secret} tls.prometheus ./prometheus/ssl/aeprometheus_server_key.pem ./prometheus/ssl/aeprometheus_server_cert.pem ${namespace}
${ae_install_tls_secret} tls.grafana ./grafana/ssl/grafana_server_key.pem ./grafana/ssl/grafana_server_cert.pem ${namespace}

anmt "${env_name} - sleeping for 10 seconds before checking Redis"
sleep 10

anmt "${env_name} - checking restored ticker pricing data in redis: ${ae_view_ticker_data_in_redis}"
${ae_view_ticker_data_in_redis}

anmt "${env_name} - starting monitoring: ${ae_monitor_start}"

${ae_monitor_start}

anmt "${env_name} - sleeping for 10 seconds before checking pods"
sleep 10

anmt "${env_name} - getting kubernetes ae pods:"
kubectl get pods -n ${namespace}

good "done - ${env_name} - build helm charts=${build_helm_charts} then starting with helm: ae=${ae} redis=${redis} minio=${minio} KUBECONFIG=${KUBECONFIG}"
anmt "--------------------------------"

cd ${cur_dir}
exit 0
