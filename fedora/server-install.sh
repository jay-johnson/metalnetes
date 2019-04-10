#!/bin/bash

use_path="./fedora"
path_to_sshd="${use_path}/etc/ssh/sshd_config"
if [[ ! -e ${path_to_sshd} ]]; then
    use_path="."
    path_to_sshd="${use_path}/etc/ssh/sshd_config"
fi
if [[ ! -e ${path_to_sshd} ]]; then
    err "$(hostname) - failed to find path to sshd_config to start: ${path_to_sshd} last path tested: ${use_path}"
    exit 1
else
    # load the logger with dates in logs
    export USE_SHOW_DATES=1
    source ${use_path}/../tools/bash_colors.sh
fi

anmt "Sleeping to let you stop this with: ctrl + c"
sleep 1
anmt "starting in 5"
sleep 1
anmt "starting in 4"
sleep 1
warn "starting in 3"
sleep 1
warn "starting in 2"
sleep 1
warn "starting in 1"
sleep 1

anmt "$(hostname) - starting install by loading ssh for access - please clean up the sshd configs after this finishes to prevent ssh access"

service_file=${use_path}/docker.service
path_to_dns_installer=${use_path}/install-dns.sh
install_go_tool=${use_path}/../tools/install-go.sh

if [[ -e ${path_to_sshd} ]]; then
    cp ${path_to_sshd} /etc/ssh/sshd_config
    systemctl restart sshd
fi

anmt "$(hostname) - starting rpm install"

dnf -y remove docker \
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

anmt "$(hostname) - updating all"
dnf update -y

anmt "$(hostname) - installing rpms"
dnf install -y \
    arp-scan \
    autoconf \
    automake \
    bind \
    binutils \
    boost \
    boost-devel \
    bzip2 \
    ca-certificates \
    cmake \
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
    python3-devel
    python3-virtualenv \
    python36 \
    redis \
    rsyslog \
    s3cmd \
    spice-server \
    sqlite \
    sqlite-devel \
    sshpass \
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
    virt-viewer \
    wget \
    which \
    xauth \
&& dnf clean all

anmt "$(hostname) - setting to permissive"
setenforce 0

anmt "$(hostname) - installing dnf-plugins-core"
dnf -y install dnf-plugins-core

inf "$(hostname) - installing dnf-utils, device mapper and lvm2"
dnf install -y dnf-utils \
    device-mapper-persistent-data \
    lvm2

inf "$(hostname) - adding docker repo"
dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/fedora/docker-ce.repo

inf "$(hostname) - enabling multipath support"
/sbin/mpathconf --enable

inf "$(hostname) - installing docker-ce"
dnf install -y docker-ce

if [[ "${METAL_USER}" != "" ]]; then
    found_user=$(cat /etc/passwd | grep ${METAL_USER} | wc -l)
    if [[ "${found_user}" == "1" ]]; then
        inf "$(hostname) - adding ${METAL_USER} to docker"
        usermod -aG docker ${METAL_USER}
    fi
fi

if [[ ! -e /data/docker ]]; then
    inf "$(hostname) - setting up docker data directory to: /data/docker"
    mkdir -p -m 777 /data/docker
fi

if [[ -e ${service_file} ]]; then
    is_diff=$(diff ${service_file} /usr/lib/systemd/system/docker.service | wc -l)
    if [[ "${is_diff}" == "1" ]]; then
        inf "$(hostname) - installing docker service file: cp ${service_file} /usr/lib/systemd/system/docker.service"
        cp ${service_file} /usr/lib/systemd/system/docker.service
        inf "$(hostname) - reloading - systemctl daemon-reload"
        systemctl daemon-reload
    fi
else
    warn "Missing Fedora docker service file: ${service_file} to /usr/lib/systemd/system/docker.service"
fi

test_exists=$(which go | wc -l)
if [[ "${test_exists}" == "0" ]]; then
    inf "$(hostname) - installing go: ${install_go_tool}"
    ${install_go_tool}
fi

# to check the loaded kernel modules, use
anmt "$(hostname) - Checking Fedora kernel modules: ${required_kernel_modules} from: https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs"
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
    inf "$(hostname) - starting docker" 
    systemctl start docker
    inf "$(hostname) - enabling docker to start on reboot" 
    systemctl enable docker
fi

anmt "$(hostname) - installing kvm"
dnf -y install bridge-utils libvirt virt-install qemu-kvm libvirt-nss \
anmt "$(hostname) - installing virt-top"
dnf -y install virt-top
anmt "$(hostname) - installing libguestfs-tool"
dnf -y install libguestfs-tool
dnf -y group install --with-optional virtualization
systemctl start libvirtd
systemctl enable libvirtd

anmt "$(hostname) - installing docker-compose"
dnf -y install docker-compose

anmt "$(hostname) - generating root ssh keys"
ssh-keygen -t rsa -f /root/.ssh/id_rsa -P ""

###############################
#
# Optionals
#
###############################

# Kubernetes

anmt "$(hostname) - installing kuberentes from guide: https://kubernetes.io/docs/tasks/tools/install-kubectl/"

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubectl
kubectl completion bash

mkdir -p -m 777 /opt/k8
ssh-keygen -t rsa -f /opt/k8/id_rsa -P ""

good "$(hostname) - done installing kuberentes"

# end of Kubernetes

# DNS
# https://www.hiroom2.com/2018/12/04/fedora-29-bind-en/
anmt "$(hostname) - installing dns using tool: ${path_to_dns_installer}"
${path_to_dns_installer}
if [[ "$?" != "0" ]]; then
    err "failed installing dns: ${path_to_dns_installer}"
    exit 1
fi

# end of DNS

good "$(hostname) - server install"
anmt "-----------------------------------------------"

exit 0
