#!/bin/bash

# Console output colors
bold() { echo -e "\e[1m$@\e[0m" ; }
red() { echo -e "\e[31m$@\e[0m" ; }
green() { echo -e "\e[32m$@\e[0m" ; }
yellow() { echo -e "\e[33m$@\e[0m" ; }

die() { red "ERR: $@" >&2 ; exit 2 ; }
silent() { "$@" > /dev/null 2>&1 ; }
output() { echo -e "- $@" ; }
outputn() { echo -en "- $@ ... " ; }
ok() { green "${@:-OK}" ; }

inf() {output $@}
anmt() {yellow $@}
good() {green $@}
err() {red $@}

anmt "--------------------------------"
anmt "$(hostname) - starting cloud-init script"

anmt "$(hostname) - uninstalling old docker if found"
test_old_docker_installed=$(rpm -qa | grep docker | grep -vi docker-ce | grep -vi docker-ee | wc -l)
if [[ "${test_old_docker_installed}" != "0" ]]; then
    warn "uninstalling previous docker versions"
    yum -y remove docker \
        docker-client \
        docker-client-latest \
        docker-common \
        docker-latest \
        docker-latest-logrotate \
        docker-logrotate \
        docker-selinux \
        docker-engine-selinux \
        docker-engine

    if [[ -e /var/lib/docker ]]; then
        anmt "deleting previous docker directory: /var/lib/docker"
        rm -rf /var/lib/docker
    fi
fi

anmt "$(hostname) - updating repositories"
yum update -y

anmt "$(hostname) - installing rpms"
yum install -y \
    autoconf \
    automake \
    binutils \
    boost \
    boost-devel \
    bzip2 \
    ca-certificates \
    curl \
    curl-devel \
    device-mapper-multipath \
    freetype \
    freetype-devel \
    dejavu-fonts-common \
    gcc \
    gcc-c++ \
    gcc-gfortran \
    git \
    hostname \
    ipvsadm \
    libaio \
    libattr-devel \
    libpng \
    libpng-devel \
    libSM \
    libxml2-devel \
    libXrender \
    libxslt \
    libxslt-devel \
    llvm \
    llvm-devel \
    logrotate \
    make \
    mariadb-devel \
    mlocate \
    net-tools \
    openssh \
    openssh-clients \
    openssl-devel \
    pandoc \
    postgresql-devel \
    procps \
    pwgen \
    python-devel \
    python-setuptools \
    python-pip \
    python-virtualenv \
    rsyslog \
    sqlite \
    sqlite-devel \
    strace \
    sudo \
    tar \
    telnet \
    tree \
    tkinter \
    unzip \
    vim \
    vim-enhanced \
    wget \
    which \
    xauth \
&& yum clean all

anmt "$(hostname) - installing yum-utils, device mapper and lvm2"
yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2

anmt "$(hostname) - enabling multipath support"
/sbin/mpathconf --enable

anmt "$(hostname) - adding centos docker-ce repo"
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

anmt "$(hostname) - installing docker-ce"
yum install -y docker-ce

if [[ ! -e /data/docker ]]; then
    anmt "setting up docker data directory to: /data/docker"
    mkdir -p -m 777 /data/docker
fi

anmt "done - $(hostname) - running cloud-init script"
anmt "----------------------------------------------"

exit 0
