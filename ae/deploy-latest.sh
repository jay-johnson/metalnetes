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
use_repo="${USE_REPO}"
s3_bucket="${AE_BACKUP_S3_BUCKET}"
engine_container="ae-workers"
ae_k8_pod_engine="ae-engine"
ae_k8_importer="${use_repo}/ae/scripts/sa.py"
use_venv="/opt/venv"

if [[ "${1}" != "" ]]; then
    namespace="${1}"
fi
if [[ "${2}" != "" ]]; then
    use_repo="${2}"
fi

# defined in CLUSTER_CONFIG
anmt "Checking the the virtualenv=${use_venv} has awscli installed"
anmt "ensure_virtualenv_has_pip_or_exit ${use_venv} awscli"
ensure_virtualenv_has_pip_or_exit ${use_venv} awscli

cur_date=$(date)
anmt "-------------------------------------------"
anmt "${cur_date} - starting ${env_name} ae deployment and auto-deploy S3 backups to Redis (in k8 and docker)"
anmt "${cur_date} - KUBECONFIG=${KUBECONFIG}"

load_s3_env_keys() {
    critical "TODO - set up secrets from ae namespace"
}

load_s3_env_keys

anmt "Getting latest date keys with: aws s3 ls s3://${s3_bucket} | grep archive | grep -o '.\{15\}$' | sort | uniq | tail -1 | sed -e 's/\.json//g'"
latest_date=$(aws s3 ls s3://${s3_bucket} | grep archive | grep -o '.\{15\}$' | sort | uniq | tail -1 | sed -e 's/\.json//g')
anmt "found latest date: ${latest_date}"
use_date=${latest_date}
use_date=2019-03-08
anmt "Getting latest keys for date=${use_date} in S3 with: aws s3 ls s3://${s3_bucket} | grep 'archive_' | grep ${use_date} | awk '{print $NF}'"
latest_keys=$(aws s3 ls s3://${s3_bucket} | grep 'archive_' | grep ${use_date} | awk '{print $NF}')

today_date=$(date +"%Y-%m-%d")
path_to_backup_dir="/data2/ae/backup_${today_date}"
mkdir -p -m 777 ${path_to_backup_dir}
anmt "using backup dir: ${path_to_backup_dir}"
cd ${path_to_backup_dir}

for key in ${latest_keys}; do
    if [[ ! -e ${key} ]]; then
        anmt "downloading ${s3_bucket}/${key} to ${path_to_backup_dir}"
        s3cmd get s3://${s3_bucket}/${key}
    else
        inf " - already have ${s3_bucket}/${key} in ${path_to_backup_dir}"
    fi
    use_key_file=${path_to_backup_dir}/${key}
    if [[ -e ${use_key_file} ]]; then
        ticker=$(ls ${use_key_file} | sed -e 's/archive_/ /g' | sed -e 's/\.json/ /g' | sed -e "s/-${use_date}//g" | awk '{print $NF}')
        inf "deploying ${ticker} to k8 - ${use_key_file} to ${pod_name}:/tmp"
        /usr/bin/kubectl -n ${namespace} cp ${use_key_file} ${pod_name}:/tmp
        anmt "importing ${ticker} dataset with: /usr/bin/kubectl -n ${namespace} exec ${pod_name} -- ${use_venv}/bin/python ${ae_k8_importer} -m 0 -t ${ticker} -L /tmp/${key}"
        /usr/bin/kubectl -n ${namespace} exec ${pod_name} -- ${use_venv}/bin/python ${ae_k8_importer} -m 0 -t ${ticker} -L /tmp/${key}
    else
        err "Failed to download: ${key} to ${use_key_file}"
    fi
done

cur_date=$(date)
anmt "${cur_date} - Getting docker containers:"
docker ps

cur_date=$(date)
anmt "${cur_date} - Getting k8 pods:"
kubectl -n ${namespace} get po

cur_date=$(date)
anmt "${cur_date} - done deploying AE"
anmt "-------------------------------------------"

exit 0
