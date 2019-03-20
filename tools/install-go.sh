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

if [[ "${GO_VERSION}" == "" ]]; then
    GO_VERSION="1.11.4"
fi

env_name="${K8_ENV}"
GO_OS="linux"
GO_ARCH="amd64"
go_file="go${GO_VERSION}.${GO_OS}-${GO_ARCH}.tar.gz"
url_file="https://dl.google.com/go/${go_file}"
download_file="/tmp/${go_file}"

anmt "-------------------------"
anmt "${env_name}:$(hostname) - installing go=${GO_VERSION}"

export GOPATH=$HOME/go/bin
export PATH=$PATH:$GOPATH:$GOPATH/bin

test_exists=$(grep "GOPATH" ~/.bashrc | wc -l)
if [[ "${test_exists}" == "0" ]]; then
    echo "" >> ~/.bashrc
    date_installed=$(date -u "+%Y-%m-%d %H:%M:%S")
    echo "# go_installed_by_metalnetes: ${date_installed}" >> ~/.bashrc
    echo "export GOPATH=\$HOME/go/bin" >> ~/.bashrc
fi

test_exists=$(grep "GOPATH" ~/.bashrc | grep " PATH=" | wc -l)
if [[ "${test_exists}" == "0" ]]; then
    echo "export PATH=\$PATH:\$GOPATH:\$GOPATH/bin" >> ~/.bashrc
fi

test_exists=$(which go | wc -l)
if [[ "${test_exists}" != "0" ]]; then
    good "already have go installed with version: $(go version)"
else
    if [[ ! -e ${download_file} ]]; then
        anmt "downloading go: ${GO_VERSION} url: ${url_file} to file: ${download_file}"
        curl -s ${url_file} --output ${download_file}
    fi

    if [[ ! -e ${GOHOME} ]]; then
        anmt "extracting go into $HOME with: tar -C $HOME -xzf ${download_file}"
        tar -C $HOME -xzf ${download_file}
    fi

    if [[ ! -e $GOPATH/bin/expenv ]]; then
        if [[ -e $GOPATH/go ]]; then
            anmt "installing expenv - to \$GOPATH=${GOPATH}/bin/expenv"
            $GOPATH/go get github.com/blang/expenv
            if [[ -e $GOPATH/bin/expenv ]]; then
                good " - installed expenv to: ${GOPATH}/bin/expenv"
            else
                err "FAILED to install expenv with ${GOPATH}/go get github.com/blang/expenv to: ${GOPATH}/bin/expenv"
                exit 1
            fi
        else
            err "missing \$GOPATH for go $GOPATH/go"
            exit 1
        fi
    else
        anmt "already have \$GOPATH expenv: $GOPATH/bin/expenv"
    fi
fi

good "done - ${env_name}:$(hostname) - installing go=${GO_VERSION}"
anmt "-------------------------"

exit 0
