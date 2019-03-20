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
registry_compose_file="${REGISTRY_COMPOSE_FILE}"
registry_user=${REGISTRY_USER}
registry_password=${REGISTRY_PASSWORD}
registry_base=${REGISTRY_VOLUME_BASE}
registry_auth_dir=${REGISTRY_AUTH_DIR}
registry_data_dir=${REGISTRY_DATA_DIR}
debug="${METAL_DEBUG}"

########################################

for i in "$@"
do
    contains_equal=$(echo ${i} | grep "=")
    if [[ "${i}" == "-d" ]]; then
        debug="1"
    else
        err "unsupported argument: ${i}"
        exit 1
    fi
done

anmt "----------------------------------------------"
anmt "deploying private docker registry on ${env_name} KUBECONFIG=${KUBECONFIG}"

if [[ ! -e ${registry_base} ]]; then
    sudo mkdir -p -m 777 ${registry_base}
fi
if [[ ! -e ${registry_auth_dir} ]]; then
    sudo mkdir -p -m 777 ${registry_auth_dir}
    docker run --entrypoint htpasswd registry:2 -Bbn ${registry_user} ${registry_password} > ${registry_auth_dir}/htpasswd
fi
if [[ ! -e ${registry_data_dir} ]]; then
    sudo mkdir -p -m 777 ${registry_data_dir}
fi

inf " - starting registry:"
anmt "docker-compose -f ${registry_compose_file} up -d >> /dev/null 2>&1"
# assumes /usr/local/bin is on the PATH env var usually for docker-compose:
docker-compose -f ${registry_compose_file} up -d >> /dev/null 2>&1
if [[ "$?" != "0" ]]; then
    err "failed deploying private docker registry with command:"
    echo "docker-compose -f ${registry_compose_file} up -d"
    warn "note: you can also disable this by setting this value in the CLUSTER_CONFIG:"
    warn "export START_REGISTRY=\"0\""
    exit 1
fi

cur_date=$(date)
not_done=$(docker inspect registry | grep -i status | sed -e 's/"/ /g' | awk '{print $3}' | grep -i running | wc -l)
while [[ "${not_done}" == "0" ]]; do
    inf "${cur_date} - sleeping to let the docker registry start"
    sleep 10
    not_done=$(docker inspect registry | grep -i status | sed -e 's/"/ /g' | awk '{print $3}' | grep -i running | wc -l)
    cur_date=$(date)
done

cur_date=$(date)
anmt "${cur_date} - checking docker registry is in running state:"
is_running=$(docker inspect registry | grep -i status | sed -e 's/"/ /g' | awk '{print $3}' | grep -i running | wc -l)
if [[ "${is_running}" == "1" ]]; then
    good "registry is in a running state"
else
    err "registry is not in a running state"
    docker ps | grep registry
    exit 1
fi

docker ps | grep registry

good "done - deploying private docker registry on ${env_name} KUBECONFIG=${KUBECONFIG}"
anmt "----------------------------------------------"

exit 0
