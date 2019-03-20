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
export CLUSTER_CONFIG=${path_to_env}

if [[ "${HTOP_VERSION}" == "" ]]; then
    HTOP_VERSION="2.2.0"
fi

env_name="${K8_ENV}"
download_file="https://github.com/hishamhm/htop/archive/${HTOP_VERSION}.tar.gz"

found_htop=$(which htop | wc -l)
if [[ "${found_htop}" != "0" ]]; then
    good "${env_name}:$(hostname) - htop installed"
    exit 0
fi

anmt "-------------------------"
anmt "${env_name}:$(hostname) - installing htop=${HTOP_VERSION}"

anmt "installing ncurses ncurses-devel automake autoconf"
yum install ncurses ncurses-devel automake autoconf

anmt "downloading htop: ${download_file}"
wget ${download_file} -O /tmp/htop.tgz

cd /tmp
anmt "extracting /tmp/htop.tgz"
tar xvf /tmp/htop.tgz >> /dev/null
inf ""
ls -lrt /tmp | grep htop
inf ""
cd htop-${HTOP_VERSION}

anmt "configuring htop in dir=$(pwd)"
./autogen.sh
if [[ "$?" != "0" ]]; then
    err "failed to run htop: ./autogen.sh"
    exit 1
fi
./configure
if [[ "$?" != "0" ]]; then
    err "failed to run htop: ./configure"
    exit 1
fi
anmt "making"
make -j4
if [[ "$?" != "0" ]]; then
    err "failed to run htop: make"
    exit 1
fi
anmt "installing"
make install

if [[ -e /tmp/htop.tgz ]]; then
    rm -f /tmp/htop.tgz
fi

if [[ -e /tmp/htop-${HTOP_VERSION} ]]; then
    rm -f /tmp/htop-${HTOP_VERSION}
fi

good "done - ${env_name}:$(hostname) - installing htop=${HTOP_VERSION}"
anmt "-------------------------"

exit 0
