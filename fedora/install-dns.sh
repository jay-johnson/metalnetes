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
allow_query="${KVM_NAMED_ALLOW_QUERY_DNS_CIDR}"

anmt "-----------------------------------------------"
anmt "$(date) - ${env_name} - installing dns ${K8_DOMAIN} with IP=${K8_DNS_SERVER_1} ALLOW_QUERY_DNS_CIDR=${allow_query}"

change_named_conf="1"
if [[ -e /etc/named.conf ]]; then
    test_exists=$(cat /etc/named.conf | grep "${K8_DOMAIN}" | wc -l)
    if [[ "${test_exists}" != "0" ]]; then
        change_named_conf="0"
    fi
fi
if [[ "${change_named_conf}" == "1" ]]; then
    cat <<EOF | tee -a /etc/named.conf
zone "${K8_DOMAIN}" in {
    type master;
    file "${K8_DOMAIN}.zone";
};
EOF
    sed -e "s:allow-query.*:allow-query { ${allow_query}; localhost; };:g" -e "s:listen-on port.*:listen-on port 53 { ${allow_query};127.0.0.1; };:g" -i /etc/named.conf
fi

anmt "$(date) - creating dns zone file: /var/named/${K8_DOMAIN}.zone"
cat <<EOF | sudo tee /var/named/${K8_DOMAIN}.zone
\$TTL 86400

@ IN SOA ${K8_DOMAIN} root.${K8_DOMAIN} (
  2017010302
  3600
  900
  604800
  86400
)

;
;check out the guide:
;https://www.server-world.info/en/note?os=Fedora_29&p=dns&f=6
;

;
;@	IN	NS	localhost.
;@	IN	A	127.0.0.1
;@	IN	AAAA	::1

;Name Server Information
        IN      NS      ns1.${K8_DOMAIN}.
;IP address of Name Server
ns1     IN       A      192.168.0.100
home1   IN       A      192.168.0.100

;bastion
bastion IN       A      192.168.0.240
;ns2
ns2 IN           A      192.168.0.200

;Mail Exchanger
;example.com.   IN     MX   10   mail.${K8_DOMAIN}.

;A - Record HostName To Ip Address
;@       IN       A      192.168.0.101
master1 IN       A      192.168.0.101
master2 IN       A      192.168.0.102
master3 IN       A      192.168.0.103
api     IN       A      192.168.0.101
ceph    IN       A      192.168.0.101
mail    IN       A      192.168.0.101
minio   IN       A      192.168.0.101
pgadmin IN       A      192.168.0.101
s3      IN       A      192.168.0.101
www     IN       A      192.168.0.101
api     IN       A      192.168.0.102
jupyter IN       A      192.168.0.102
sajupyter IN     A      192.168.0.102
splunk  IN       A      192.168.0.103

c1      IN       A      192.168.0.104
c2      IN       A      192.168.0.105
c3      IN       A      192.168.0.106

; metalbase server
metalbase IN         A      192.168.0.200

; metalnetes k8.env default dev cluster:
m10     IN           A      192.168.0.110
m11     IN           A      192.168.0.111
m12     IN           A      192.168.0.112
aeminio IN           A      192.168.0.112
aejupyter IN         A      192.168.0.112
aeprometheus IN      A      192.168.0.112
grafana IN           A      192.168.0.112

; metal - dev
m13     IN           A      192.168.0.113
m14     IN           A      192.168.0.114
m15     IN           A      192.168.0.115
dev-grafana IN       A      192.168.0.114
dev-aeminio IN       A      192.168.0.114
dev-aejupyter IN     A      192.168.0.114
dev-aeprometheus IN  A      192.168.0.114

; metal - prod
m16     IN           A      192.168.0.116
m17     IN           A      192.168.0.117
m18     IN           A      192.168.0.118
prod-grafana IN      A      192.168.0.117
prod-aeminio IN      A      192.168.0.117
prod-aejupyter IN    A      192.168.0.117
prod-aeprometheus IN A      192.168.0.117

EOF

anmt "$(date) - setting permissions on dns zone file: chown named:named /var/named/${K8_DOMAIN}.zone"
chown named:named /var/named/${K8_DOMAIN}.zone

systemctl stop named
systemctl start named
systemctl enable named

systemctl stop dnsmasq
systemctl disable dnsmasq

named-checkconf

devices="${K8_VM_BRIDGE} eno1"

for d in ${devices}; do
    anmt "setting nmcli con mod ${d} ipv4.dns \"${K8_DNS_SERVER_1} 8.8.8.8 8.8.4.4\""
    nmcli con mod "${d}" ipv4.dns "${K8_DNS_SERVER_1} 8.8.8.8 8.8.4.4"
    if [[ "$?" != "0" ]]; then
        err "$(date) - ${env_name} failed setting device=${d} to use ipv4.dns \"${K8_DNS_SERVER_1} 8.8.8.8 8.8.4.4\""
        exit 1
    fi
done

good "done - $(date) - ${env_name} - installing dns ${K8_DOMAIN} with IP=${K8_DNS_SERVER_1}"
anmt "-----------------------------------------------"

exit 0
