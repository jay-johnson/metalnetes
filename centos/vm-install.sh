#!/bin/bash

cur_dir=$(pwd)
path_to_env="${cur_dir}/k8.env"
if [[ "${CLUSTER_CONFIG}" != "" ]]; then
    path_to_env="${CLUSTER_CONFIG}"
fi
if [[ ! -e ${path_to_env} ]]; then
    echo "failed to find env file: ${path_to_env} with CLUSTER_CONFIG=${CLUSTER_CONFIG} on host=$(hostname)"
    ls -lrt /opt/
    exit 1
fi
source ${path_to_env}

env_name="${K8_ENV}"
nodes="${K8_NODES}"
k8_config_dir="${K8_CONFIG_DIR}"
k8_dns_server_1="${K8_DNS_SERVER_1}"
k8_domain="${K8_DOMAIN}"

user=$(whoami)
if [[ "${user}" != "root" ]]; then
    err "Please run the CentOS prepare tool as root to set up host=$(hostname) for ${env_name}"
    exit 1
fi

anmt "-----------------------------------------------"
anmt "${env_name}:$(hostname) ${k8_config_dir}/vm-install.sh for running kubernetes DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"

custom_user=$(cat /etc/group | grep jay | wc -l)
service_file="${k8_config_dir}/docker.service"
kernel_modules_file="${k8_config_dir}/kernel-modules.conf"
required_kernel_modules="ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4"

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
        inf "deleting previous docker directory: /var/lib/docker"
        rm -rf /var/lib/docker
    fi
fi

inf "updating repositories"
yum update -y

inf "installing rpms"
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
    lsof \
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

inf "installing yum-utils, device mapper and lvm2"
yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2

inf "enabling multipath support"
/sbin/mpathconf --enable

inf "adding centos docker-ce repo"
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

inf "installing docker-ce"
yum install -y docker-ce

if [[ "${custom_user}" != "0" ]]; then
    usermod -aG docker jay
fi

if [[ ! -e /data/docker ]]; then
    inf "setting up docker data directory to: /data/docker"
    mkdir -p -m 777 /data/docker
fi

if [[ -e ${service_file} ]]; then
    is_diff=$(diff ${service_file} /usr/lib/systemd/system/docker.service | wc -l)
    if [[ "${is_diff}" == "1" ]]; then
        inf "installing docker service file: cp ${service_file} /usr/lib/systemd/system/docker.service"
        cp ${service_file} /usr/lib/systemd/system/docker.service
        inf "reloading - systemctl daemon-reload"
        systemctl daemon-reload
    fi
else
    warn "Missing CentOS docker service file: ${service_file} to /usr/lib/systemd/system/docker.service"
fi

if [[ -e ${kernel_modules_file} ]]; then
    inf "installing kernel modules: cp -f ${kernel_modules_file} /etc/modules-load.d/ip_vs.conf"
    cp -f ${kernel_modules_file} /etc/modules-load.d/ip_vs.conf
else
    warn "Missing CentOS kernel modules file: ${kernel_modules_file} for installing to /etc/modules-load.d/ip_vs.conf"
fi

test_exists=$(which go | wc -l)
if [[ "${test_exists}" == "0" ]]; then
    inf "installing go"
    ${k8_config_dir}/install-go.sh
fi

# to check the loaded kernel modules, use
anmt "${env_name}:$(hostname) - Checking CentOS kernel modules: ${required_kernel_modules} from: https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs"
for i in ${required_kernel_modules}; do
    test_exists=$(lsmod | grep ${i} | wc -l)
    if [[ "${test_exists}" == "0" ]]; then
        inf " - kernel module: ${i} is installed:"
        modprobe -- ${i}
        test_exists=$(lsmod | grep ${i} | wc -l)
        if [[ "${test_exists}" == "0" ]]; then
            err "Failed loading required kube-proxy kernel module: ${i}"
            err "please ensure this host supports the required kernel modules for kube-proxy: https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs"
            exit 1
        fi
    else
        inf " - kernel module already loaded: ${i}"
    fi
done

test_running=$(systemctl status docker | grep "Active: active" | wc -l)
if [[ "${test_running}" == "0" ]]; then
    inf "starting docker" 
    systemctl start docker
    inf "enabling docker to start on reboot" 
    systemctl enable docker
fi

good "done - ${env_name}:$(hostname) ${k8_config_dir}/vm-install.sh for running kubernetes DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
anmt "-----------------------------------------------"
