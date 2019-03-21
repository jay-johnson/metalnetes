#!/bin/bash

# enable dates in the logs
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

job_name="intra"
ae_deploy_dir="${AE_DEPLOY_DIR}"
log="${AE_JOB_LOG}"

if [[ "${1}" != "" ]]; then
    job_name=${1}
fi
if [[ "${2}" != "" ]]; then
    export KUBECONFIG=${2}
fi
# allow changing to external job runners outside this repo
if [[ "${3}" != "" ]]; then
    ae_deploy_dir=${3}
fi
if [[ "${4}" != "" ]]; then
    log=${4}
fi

ae_intraday_job="${ae_deploy_dir}/run-intraday-job.sh"
ae_daily_job="${ae_deploy_dir}/run-daily-job.sh"
ae_weekly_job="${ae_deploy_dir}/run-weekly-job.sh"
ae_backup_job="${ae_deploy_dir}/run-backup-job.sh"
ae_restore_job="${ae_deploy_dir}/run-restore-job.sh"

anmt "------------------------------------------------------" >> ${log}
anmt "${env_name} - starting ae job=${job_name} AE_DEPLOY_DIR=${ae_deploy_dir} KUBECONFIG=${KUBECONFIG}" >> ${log}

cd ${ae_deploy_dir} >> /dev/null

# helm on ubuntu installs to /snap/bin
export PATH=${PATH}:/usr/local/bin:/snap/bin

test_helm=$(which helm | wc -l)
if [[ "${test_helm}" == "0" ]]; then
    err "${env_name} - please add helm to the cron job PATH=${PATH} env variable - unable to find helm - stopping" >> ${log}
    exit 1
fi

if [[ "${job_name}" == "intra" ]]; then
    anmt "${env_name} - running: ${ae_intraday_job}" >> ${log}
    ${ae_intraday_job} -r >> ${log} 2>&1
    if [[ "$?" != "0" ]]; then
        err "failed running intraday job on: ${env_name} - with: ${ae_intraday_job}" >> ${log}
        exit 1
    fi
elif [[ "${job_name}" == "daily" ]]; then
    anmt "${env_name} - running: ${ae_daily_job}" >> ${log}
    ${ae_daily_job} -r >> ${log} 2>&1
    if [[ "$?" != "0" ]]; then
        err "failed running daily job on: ${env_name} - with: ${ae_daily_job}" >> ${log}
        exit 1
    fi
elif [[ "${job_name}" == "weekly" ]]; then
    anmt "${env_name} - running: ${ae_weekly_job}" >> ${log}
    ${ae_weekly_job} -r >> ${log} 2>&1
    if [[ "$?" != "0" ]]; then
        err "failed running weekly job on: ${env_name} - with: ${ae_weekly_job}" >> ${log}
        exit 1
    fi
elif [[ "${job_name}" == "backup" ]]; then
    anmt "${env_name} - running: ${ae_backup_job}" >> ${log}
    ${ae_backup_job} -r >> ${log} 2>&1
    if [[ "$?" != "0" ]]; then
        err "failed running backup job on: ${env_name} - with: ${ae_backup_job}" >> ${log}
        exit 1
    fi
elif [[ "${job_name}" == "restore" ]]; then
    anmt "${env_name} - running: ${ae_restore_job}" >> ${log}
    ${ae_restore_job} -r >> ${log} 2>&1
    if [[ "$?" != "0" ]]; then
        err "failed running restore job on: ${env_name} - with: ${ae_restore_job}" >> ${log}
        exit 1
    fi
else
    err "${env_name} - unsupported job=${job_name} with ae_deploy_dir=${ae_deploy_dir}" >> ${log} 2>&1
fi

cd ${cur_dir}
good "${env_name} - done running ae job=${job_name} AE_DEPLOY_DIR=${ae_deploy_dir} KUBECONFIG=${KUBECONFIG}" >> ${log}
anmt "------------------------------------------------------" >> ${log}

exit 0
