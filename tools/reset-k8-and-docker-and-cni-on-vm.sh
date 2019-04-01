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

user_test=$(whoami)
if [[ "${user_test}" != "root" ]]; then
    err "please run as root"
    exit 1
fi

env_name="${K8_ENV}"
docker_data_dir="${DOCKER_DATA_DIR}"
cni_installer="${REMOTE_TOOL_CNI_INSTALLER}"
dir_to_check="${REMOTE_CNI_DIR}"

anmt "-------------------------"
warn "$(date) - ${env_name}:$(hostname) - start - resetting vm services: kubernetes and docker and cni"

# https://github.com/kubernetes/kubernetes/issues/39557#issuecomment-271944481
# and
# https://stackoverflow.com/questions/41359224/kubernetes-failed-to-setup-network-for-pod-after-executed-kubeadm-reset
# https://kubernetes.io/docs/setup/independent/troubleshooting-kubeadm/#kubeadm-blocks-when-removing-managed-containers
# 2019-03-31 - kubernetes v1.14 looks like it changed the cleanup process
inf "$(date) - ${env_name}:$(hostname) - restarting docker"
systemctl restart docker
inf "$(date) - ${env_name}:$(hostname) - sleeping for 5 seconds"
sleep 5

background_script="/tmp/background-k8-reset.sh"
if [[ -e ${background_script} ]]; then
    rm -f ${background_script}
fi
inf "$(date) - ${env_name}:$(hostname) - creating reset tool: ${background_script}"
cat <<EOF > ${background_script}
#!/bin/bash
echo "resetting kubelet"
kubeadm reset -f
exit 0
EOF

inf "$(date) - ${env_name}:$(hostname) - starting kubeadm reset background script: ${background_script}"
chmod 777 ${background_script}
nohup ${background_script} &

inf "$(date) - ${env_name}:$(hostname) - sleeping 15 seconds to let background script finish: ${background_script}"
sleep 15

anmt "$(date) - ${env_name}:$(hostname) - starting kubeadm reset: kubeadm reset -f"
kubeadm reset -f

not_done=$(ps auwwwx | grep background-k8-reset | grep -v grep | wc -l)
while [[ "${not_done}" != "0" ]]; do
    inf "$(date) - ${env_name}:$(hostname) - waiting for background-k8-reset to finish"
    sleep 10
    not_done=$(ps auwwwx | grep background-k8-reset | grep -v grep | wc -l)
    if [[ "${not_done}" != "0" ]]; then
        inf "$(date) - ${env_name}:$(hostname) - force stopping background script: ${background_script}"
        pid_to_stop=$(ps auwwwx | grep background-k8-reset | grep -v grep | awk '{print $2}')
        kill -9 ${pid_to_stop} >> /dev/null
        not_done=$(ps auwwwx | grep background-k8-reset | grep -v grep | wc -l)
    fi
done

inf "$(date) - ${env_name}:$(hostname) - systemctl stop kubelet"
systemctl stop kubelet
inf "$(date) - ${env_name}:$(hostname) - systemctl stop docker"
systemctl stop docker

inf "$(date) - ${env_name}:$(hostname) - checking if kubelet /var/lib/kubelet dir exists"
if [[ -e /var/lib/kubelet ]]; then
    inf "$(date) - ${env_name}:$(hostname) - removing kubelet dir: /var/lib/kubelet/*"
    rm -rf /var/lib/kubelet/*
fi

inf "$(date) - ${env_name}:$(hostname) - checking if docker data dir: /var/lib/docker exists"
if [[ -e /var/lib/docker ]]; then
    inf "$(date) - ${env_name}:$(hostname) - removing docker data dir: rm -rf /var/lib/docker"
    rm -rf /var/lib/docker
    if [[ -e /var/lib/docker ]]; then
        err "$(date) - ${env_name}:$(hostname) - failed removing docker dir: /var/lib/docker"
        exit 1
    fi
fi

inf "$(date) - ${env_name}:$(hostname) - checking if optional docker data dir: ${docker_data_dir} exists"
if [[ "${docker_data_dir}" != "/" ]] && [[ -e "${docker_data_dir}" ]]; then
    inf "$(date) - ${env_name}:$(hostname) - removing optional docker data dir: rm -rf ${docker_data_dir}"
    rm -rf ${docker_data_dir}
    if [[ -e ${docker_data_dir} ]]; then
        err "$(date) - ${env_name}:$(hostname) - failed removing optional docker dir: ${docker_data_dir}"
        exit 1
    fi
fi

# Clean up cni, network devices and firewall

inf "$(date) - ${env_name}:$(hostname) - ifconfig cni0 down"
ifconfig cni0 down
inf "$(date) - ${env_name}:$(hostname) - ip link delete cni0"
ip link delete cni0
inf "$(date) - ${env_name}:$(hostname) - ifconfig flannel.1 down"
ifconfig flannel.1 down
inf "$(date) - ${env_name}:$(hostname) - ip link delete flannel.1"
ip link delete flannel.1
inf "$(date) - ${env_name}:$(hostname) - ifconfig docker0 down"
ifconfig docker0 down

inf "$(date) - ${env_name}:$(hostname) - sleeping for 5 seconds"
sleep 5

# https://blog.heptio.com/properly-resetting-your-kubeadm-bootstrapped-cluster-nodes-heptioprotip-473bd0b824aa
inf "$(date) - ${env_name}:$(hostname) - cleaning networking and firewall rules: iptables -F ; iptables -t nat -F ; iptables -t mangle -F ; iptables -X"
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -X

inf "$(date) - ${env_name}:$(hostname) - checking if cni var lib dir exists from a previous deployment: /var/lib/cni"
if [[ -e /var/lib/cni ]]; then
    inf "$(date) - ${env_name}:$(hostname) - removing cni var lib: rm -rf /var/lib/cni/"
    rm -rf /var/lib/cni/
fi

inf "$(date) - ${env_name}:$(hostname) - checking if cni config dir exists from a previous deployment: /etc/cni/"
if [[ -e /etc/cni/ ]]; then
    inf "$(date) - ${env_name}:$(hostname) - removing previous cni config dir: /etc/cni/"
    rm -rf /etc/cni/
fi

inf "$(date) - ${env_name}:$(hostname) - checking if cni dir exists from a previous deployment: ${dir_to_check}"
cur_dir=$(pwd)
if [[ -e ${dir_to_check} ]]; then
    inf "$(date) - ${env_name}:$(hostname) - cleaning cni dir from the previous deployment: ${dir_to_check}"
    cd ${dir_to_check}
    for hash in $(tail -n +1 * | egrep '^[A-Za-z0-9]{64,64}$'); do
        if [ -z $(crictl pods --no-trunc | grep $hash | awk '{print $1}') ]; then
            grep -ilr $hash ./ | xargs rm
        fi;
    done
fi
cd ${cur_dir}

# install new cni

inf "$(date) - ${env_name}:$(hostname) - installing cni: ${cni_installer}"
${cni_installer}

inf "$(date) - ${env_name}:$(hostname) - sleeping for 5 seconds"
sleep 5

if [[ -e /var/lib/rook ]]; then
    inf "$(date) - ${env_name}:$(hostname) - deleting /var/lib/rook"
    rm -rf /var/lib/rook
    if [[ -e /var/lib/rook ]]; then
        ls -rthl /var/lib/rook/*
        err "$(date) - ${env_name}:$(hostname) - failed deleting /var/lib/rook"
        exit 1
    else
        good "$(date) - ${env_name}:$(hostname) - done - deleting /var/lib/rook"
    fi
fi

if [[ -e /var/lib/ceph ]]; then
    inf "$(date) - ${env_name}:$(hostname) - deleting /var/lib/ceph"
    rm -rf /var/lib/ceph
    if [[ -e /var/lib/ceph ]]; then
        ls -rthl /var/lib/ceph/*
        err "$(date) - ${env_name}:$(hostname) - failed deleting /var/lib/ceph"
        exit 1
    else
        good "$(date) - ${env_name}:$(hostname) - done - deleting /var/lib/ceph"
    fi
fi

# start docker and kubelet

anmt "$(date) - ${env_name}:$(hostname) - starting docker: systemctl start docker"
systemctl start docker
anmt "$(date) - ${env_name}:$(hostname) - starting kubelet: systemctl start kubelet"
systemctl start kubelet
inf ""

inf "$(date) - ${env_name}:$(hostname) - checking docker and kubelet processes:"
ps auwwx | grep -E "docker|kubelet"
inf ""

good "$(date) - ${env_name}:$(hostname) - done - resetting vm services: kubernetes and docker and cni"
anmt "-------------------------"

exit 0
