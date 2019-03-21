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

namespace="ae"
engine_container="ae-workers"
ae_k8_pod_engine="ae-engine"
use_repo="${REPO_BASE_DIR}"
s3_bucket="${AE_BACKUP_S3_BUCKET}"
ae_k8_importer="${AE_LOCAL_RESTORE_MODULE}"
# path to a python 3 virtual environment for ae (by default '/opt/venv')
# install guide: https://github.com/AlgoTraders/stock-analysis-engine#running-on-ubuntu-and-centos
use_venv="${AE_VENV}"

if [[ "${1}" != "" ]]; then
    namespace="${1}"
fi
if [[ "${2}" != "" ]]; then
    use_repo="${2}"
fi

# defined in CLUSTER_CONFIG
anmt "Checking the the virtualenv AE_VENV=${use_venv} has awscli installed with:"
anmt "ensure_virtualenv_has_pip_or_exit ${use_venv} awscli"
ensure_virtualenv_has_pip_or_exit ${use_venv} awscli

anmt "----------------------------------"
anmt "$(date) - starting ${env_name} ae deployment and auto-deploy S3 backups to Redis (in k8 and docker)"
anmt "$(date) - KUBECONFIG=${KUBECONFIG}"

test_s3cmd=$(which s3cmd | wc -l)
if [[ "${test_s3cmd}" == "0" ]]; then
    err "failed to find s3cmd - please install s3cmd from: https://s3tools.org/s3cmd"
    exit 1
fi

pod_name=$(kubectl -n ${namespace} get pod --ignore-not-found | grep ${ae_k8_pod_engine} | awk '{print $1}' | head -1)
if [[ "${pod_name}" == "" ]]; then
    err "failed to restore backup because ${ae_k8_pod_engine} was not found running on ${env_name} - is ae running?" 
    inf "to deploy ae run:"
    inf "${AE_STARTER}"
    exit 1
else
    good "$(date) - ${env_name} - found ${ae_k8_pod_engine}=${pod_name}"
fi

anmt "${env_name} - getting latest date keys with: aws s3 ls s3://${s3_bucket} | grep archive | grep -o '.\{15\}$' | sort | uniq | tail -1 | sed -e 's/\.json//g'"
latest_date=$(aws s3 ls s3://${s3_bucket} | grep archive | grep -o '.\{15\}$' | sort | uniq | tail -1 | sed -e 's/\.json//g')
anmt "${env_name} - found latest date: ${latest_date}"
use_date=${latest_date}
anmt "${env_name} - getting latest keys for date=${use_date} in S3 with: aws s3 ls s3://${s3_bucket} | grep 'archive_' | grep ${use_date} | awk '{print $NF}'"
latest_keys=$(aws s3 ls s3://${s3_bucket} | grep 'archive_' | grep ${use_date} | awk '{print $NF}')

if [[ ! -e ${AE_RESTORE_DOWNLOAD_DIR} ]]; then
    anmt "${env_name} - creating restore download dir: ${AE_RESTORE_DOWNLOAD_DIR}"
    mkdir -p -m 775 ${AE_RESTORE_DOWNLOAD_DIR}
    if [[ "$?" != "0" ]]; then
        err "${env_name} - failed to create restore download dir: ${AE_RESTORE_DOWNLOAD_DIR}"
        err "please confirm your user has permissions to create this dir:"
        echo "mkdir -p -m 775 ${AE_RESTORE_DOWNLOAD_DIR}"
        exit 1
    fi
fi
today_date=$(date +"%Y-%m-%d")
path_to_backup_dir="${AE_RESTORE_DOWNLOAD_DIR}/backup_${today_date}"

mkdir -p -m 777 ${path_to_backup_dir}
anmt "${env_name} - using backup dir: ${path_to_backup_dir}"
cd ${path_to_backup_dir}

for key in ${latest_keys}; do
    if [[ ! -e ${key} ]]; then
        anmt "$(date) - ${env_name} - downloading ${s3_bucket}/${key} to ${path_to_backup_dir}"
        s3cmd get s3://${s3_bucket}/${key}
    else
        inf "$(date) - ${env_name} - already have ${s3_bucket}/${key} in ${path_to_backup_dir}"
    fi
    use_key_file=${path_to_backup_dir}/${key}
    if [[ -e ${use_key_file} ]]; then
        ticker=$(ls ${use_key_file} | sed -e 's/archive_/ /g' | sed -e 's/\.json/ /g' | sed -e "s/-${use_date}//g" | awk '{print $NF}')
        inf "$(date) - ${env_name} - deploying ${ticker} to k8 - ${use_key_file} to ${pod_name}:/tmp"
        /usr/bin/kubectl -n ${namespace} cp ${use_key_file} ${pod_name}:/tmp
        anmt "$(date) - ${env_name} - importing ${ticker} dataset with: "
        anmt "/usr/bin/kubectl -n ${namespace} exec ${pod_name} -- ${use_venv}/bin/python ${ae_k8_importer} -m 0 -t ${ticker} -L /tmp/${key}"
        /usr/bin/kubectl -n ${namespace} exec ${pod_name} -- ${use_venv}/bin/python ${ae_k8_importer} -m 0 -t ${ticker} -L /tmp/${key}
    else
        err "${env_name} - failed to download: ${key} to ${use_key_file}"
    fi
done

anmt "$(date) - ${env_name} - showing ae k8 pods:"
kubectl -n ${namespace} get po

anmt "$(date) - ${env_name} - done deploying ae"
anmt "----------------------------------"

exit 0
