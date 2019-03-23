#!/bin/bash

path_to_sshd=./fc/etc/ssh/sshd_config
service_file=./fc/docker.service
if [[ -e ${path_to_sshd} ]]; then
    path_to_sshd=./fc/etc/ssh/sshd_config
    service_file=./fc/docker.service
    source ./tools/bash_colors.sh
else
    path_to_sshd=./etc/ssh/sshd_config
    service_file=./docker.service
    source ../tools/bash_colors.sh
fi
if [[ -e ${path_to_sshd} ]]; then
    cp ${path_to_sshd} /etc/ssh/sshd_config
    systemctl restart sshd
fi

anmt "starting install"

dnf remove docker \
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

inf "updating all"
dnf update -y

inf "installing rpms"
dnf install -y \
    autoconf \
    automake \
    bind \
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
    python3-virtualenv \
    python36 \
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
    virtualenv \
    wget \
    which \
    xauth \
&& dnf clean all

anmt "setting to permissive"
setenforce 0

dnf -y install dnf-plugins-core

inf "installing dnf-utils, device mapper and lvm2"
dnf install -y dnf-utils \
    device-mapper-persistent-data \
    lvm2

dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

inf "enabling multipath support"
/sbin/mpathconf --enable

inf "installing docker-ce"
dnf install -y docker-ce

inf "adding jay to docker"
usermod -aG docker jay

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

anmt "installing kvm"
dnf -y install bridge-utils libvirt virt-install qemu-kvm
anmt "installing virt"
dnf -y install virt-top libguestfs-tool
dnf -y group install --with-optional virtualization
systemctl start libvirtd
systemctl enable libvirtd

good "done - ${env_name}:$(hostname) ${k8_config_dir}/vm-install.sh for running kubernetes DNS=${k8_dns_server_1} DOMAIN=${k8_domain}"
anmt "-----------------------------------------------"
