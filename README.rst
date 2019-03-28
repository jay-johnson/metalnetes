Metalnetes
==========

Tools for managing multiple Kubernetes **1.14** clusters on KVM (3 CentOS 7 VM) running on a bare metal server running Fedora 29 (also tested on Ubuntu 18.04 until 1.13). Use this repo if you want to create, destroy and manage native Kubernetes clusters. It is a full installer for taking a brand new server up to speed using just bash and environment variables.

.. image:: https://i.imgur.com/awLwim1.png

Getting Started
---------------

This `repo <https://github.com/jay-johnson/metalnetes>`__ automates:

- installing many rpms, systems and tools to prepare a bare metal server (on Fedora 29) to host multiple Kubernetes clusters
- deploying Kubernetes clusters on 3 CentOS 7 VMs
- each VM has 100 GB, 4 cpu cores, 16 GB ram, and auto-configured for static IP assignment from env vars
- hosting VMs using KVM which requires access to the server's hypervisor (running this in a vm will not work)
- deploying a Rook Ceph storage cluster for Kubernetes persistent volumes
- installs a local dns server (named) with working example for mapping VM static ips to urls that a browser can use with any Kubernetes nginx ingress endpoint
- ssh access for manually fixing a VM after deployment
- optional - deploy the `Stock Analysis Engine <https://stock-analysis-engine.readthedocs.io/en/latest/>`__ which includes helm charts for running: Minio (on-premise s3), Redis cluster, Jupyter, Grafana + Prometheus for monitoring (required for ceph cluster monitoring)

Fedora Bare Metal Install Guide
===============================

Server Resource Requirements
----------------------------

Minimum hardware specs to run 1 cluster:

- 50 GB RAM
- 12 cpu cores
- 500 GB hdd space for each cluster (400 GB if you do not want to use base images and slow down each cluster deployment)

Clone
-----

::

    git clone https://github.com/jay-johnson/metalnetes.git
    cd metalnetes

Edit Cluster Configuration
==========================

Please edit the default `Cluster Config k8.env <https://github.com/jay-johnson/metalnetes/blob/master/k8.env>`__ as needed

Launch Checklist
----------------

Uninstalling and reinstalling clusters is not a slow process, and it helps to take a moment to review the VM's networking, Kubernetes cluster deployment, and KVM configuration before starting or testing a new idea for your next cluster deployment:

#.  `Set a name for the cluster <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L4-L8>`__
#.  KVM

    #.  `K8_VMS <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L100>`__ - short VM names for showing in ``virsh list`` and must be unique
    #.  `K8_DOMAIN <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L101>`__ - search domain for cluster ``example.com`` and must work with the dns server records and VM ip addresses
    #.  `K8_INITIAL_MASTER <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L102>`__ - initial fqdn to set ``m10.example.com``
    #.  `K8_SECONDARY_MASTERS <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L103>`__ - additional fqdns to set ``m11.example.com m12.example.com`` and space separated
#.  Networking

    #.  `Confirm VM IP Addresses <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L105-L108>`__
    #.  `Confirm VM MAC Addresses <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L109-L111>`__
    #.  `Confirm DNS <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L104>`__
#.  `Confirm User For Private Docker Registry <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L35-L39>`__
#.  `Confirm User For SSH Access to VMs <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L118-L119>`__
#.  `Confirm CPU Per VM (4 cores) <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L116>`__
#.  `Confirm Memory Per VM (16 GB ram) <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L117>`__
#.  `Confirm Storage Per VM (100 GB harddrives and qemu raw image format) <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L114>`__
#.  `Confirm Cluster Storage (rook-ceph by default) <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L57-L60>`__
#.  `Confirm Ingress (nginx by default) <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L91-L94>`__
#.  `Confirm Bridge (br0 by default) <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L115>`__
#.  `Confirm Base VM IP and Mac Address <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L208-L209>`__
#.  `Confirm Base VM Allow Query DNS CIDR <https://github.com/jay-johnson/metalnetes/blob/master/k8.env#L205>`__

Start Install
=============

Change to root and start the Fedora bare metal server installer:

::

    sudo su
    ./fedora/server-install.sh

Install Bridge
==============

This will install a bridge network device called ``br0`` from a network device ``eno1``. This ``br0`` bridge is used by KVM as a shared networking device for all VMs in all Kubernetes clusters.

::

    ./fedora/install-bridge.sh

I am not sure this is required, but I reboot the server at this point. This ensures the OS reboots correctly before creating any VMs, and I can confirm the ``br0`` bridge shows up after a clean restart using ``ifconfig -a | grep br0`` or ``nmcli dev | grep br0``.

Start the Kubernetes Cluster
============================

Boot your cluster as your user (which should have KVM access). The `boot.sh <https://github.com/jay-johnson/metalnetes/blob/master/boot.sh>`__ uses a base VM to bootstrap and speed up future deployments. Once the base VM is built, it will copy and launch 3 VMs (from the base) and install the latest Kubernetes build in all VMs. Once installed and running the 2nd and 3rd nodes join the 1st node to initialize the cluster. After initializing the cluster, helm and tiller will install and a rook-ceph storage layer will be deployed for persisting your data in volumes:

.. note:: Initial benchmarks take around 30 minutes to build all VMs and bring a new cluster online. Cleaning and restarting the cluster does not take nearly as long as creating VMs for a new cluster. Also the first time running ``./boot.sh`` will take the longest because it builds a shared base VM image to decrease future cluster deploy time.

::

    # go to the base of the repo
    cd ..
    # load your edited k8.env Cluster Config
    source k8.env
    # start
    ./boot.sh

For help with issues please refer to the `FAQ <https://github.com/jay-johnson/metalnetes#faq>`__

View Kubernetes Nodes
---------------------

Once it finishes you can view your new cluster nodes with:

::

    ./tools/show-nodes.sh

Changing Between Kubernetes Clusters
====================================

If you create a new ``k8.env`` file for each cluster, like ``dev_k8.env`` and ``prod_k8.env`` then you can then quickly toggle between clusters using:

#.  Load ``dev`` Cluster Config file

    ::

        source dev_k8.env

#.  Use the ``metal`` bash function to sync the ``KUBECONFIG`` through the ``dev`` cluster and local host

    ::

        metal

#.  Load ``prod`` Cluster Config file

    ::

        source prod_k8.env

#.  Use the ``metal`` bash function to sync the ``KUBECONFIG`` through the ``prod`` cluster and local host

    ::

        metal

Customizing the Kubernetes Cluster
==================================

If you are looking to swap out parts of the deployment, please ensure the hosting server has a replacement in place for these bare minimum components:

- a dns server that can host the ``example.com`` zone
- access to a docker-ce daemon (latest stable)
- a private docker registry
- KVM (requires **hypervisor** access)
- a network device that supports static bridging for KVM (please review the ``centos/install-network-device.sh`` for examples)
- default static network ip assignment from a router or switch that can map a VM's MAC address to a static ip address that the dns server can map to for helping browsers access nginx ingress endpoints
- access to arp-scan tool for detecting when each VM is ready for ssh scripting using dns name resolution

Before starting a second cluster there are some deployment sections to change from the default ``k8.env`` Cluster Config file.

Please review these sections to prevent debugging collision-related issues:

VM and Kubernetes Node Configuration
------------------------------------

- `VM names, Cluster Nodes, Node Labels, Cluster Tools section <https://github.com/jay-johnson/metalnetes/blob/34c0eabf5f7007056a4823f5c4ea760aea7c8e6e/k8.env#L96-L194>`__

**Considerations and Deployment Constraints**

- ``K8_ENV`` must be a unique name for the cluster (``dev`` vs ``prod`` for example)
- VM names need to be unique (and on the dns server with fqdn: ``VM_NAME.example.com`` as the default naming convention
- IPs must be unique (or the dns server will have problems)
- MAC addressess must be unique

Helm and Tiller Configuration
-----------------------------

- `Helm and Tiller <https://github.com/jay-johnson/metalnetes/blob/34c0eabf5f7007056a4823f5c4ea760aea7c8e6e/k8.env#L48-L55>`__

Cluster Storage Configuation
----------------------------

**Considerations and Deployment Constraints**

- Operator redundancy

- `Storage (rook-ceph by default) <https://github.com/jay-johnson/metalnetes/blob/34c0eabf5f7007056a4823f5c4ea760aea7c8e6e/k8.env#L57-L65>`__
- `Additional Block Devices per VM <https://github.com/jay-johnson/metalnetes/blob/34c0eabf5f7007056a4823f5c4ea760aea7c8e6e/k8.env#L178-L188>`__

Private Docker Registry
-----------------------

Please export the address to your private docker registy before deploying with format:

::

    export DOCKER_REGISTRY_FQDN=REGISTRY_HOST:PORT

- `Registry <https://github.com/jay-johnson/metalnetes/blob/34c0eabf5f7007056a4823f5c4ea760aea7c8e6e/k8.env#L35-L46>`__

Managing a Running Kubernetes Cluster
=====================================

Run these steps to manage a running kubernetes cluster.

Load the CLUSTER_CONFIG environment
-----------------------------------

::

    # from within the repo's root dir:
    export CLUSTER_CONFIG=$(pwd)/k8.env

Fully Clean and Reinitialize the Kubernetes Cluster
---------------------------------------------------

::

    ./clean.sh

Start Kubernetes Cluster with a Private Docker Registry + Rook Ceph
-------------------------------------------------------------------

::

    ./start.sh

Check Kubernetes Nodes
----------------------

::

    ./tools/show-labels.sh

Cluster Join Tool
=================

If you want to reboot VMs and have the nodes re-join and rebuild the Kubernetes cluster use:

::

    ./join.sh

Deployment Tools
================

Nginx Ingress
-------------

Deploy `the nginx ingress <https://github.com/nginxinc/kubernetes-ingress/>`__

::

    ./deploy-nginx.sh

Rook-Ceph
---------

Deploy `rook-ceph <https://rook.io/docs/rook/v0.9/ceph-quickstart.html>`__ using the `Advanced Configuration <https://rook.io/docs/rook/v0.9/advanced-configuration.html>`__

::

    ./deploy-rook-ceph.sh

Confirm Rook-Ceph Operator Started

::

    ./rook-ceph/describe-operator.sh

Private Docker Registry
-----------------------

Deploy a private docker registry for use with the cluster with:

::

    ./deploy-registry.sh

Deploy Helm
-----------

Deploy `helm <https://helm.sh/docs/>`__

::

    ./deploy-helm.sh

Deploy Tiller
-------------

Deploy tiller:

::

    ./deploy-tiller.sh

(Optional Validation) - Deploy Stock Analysis Engine
====================================================

This repository was created after trying to decouple the `AI Kubernetes cluster for analyzing network traffic <https://github.com/jay-johnson/deploy-to-kubernetes>`__ and the `Stock Analysis Engine (ae) that uses many deep neural networks to predict future stock prices during live-trading hours <https://github.com/AlgoTraders/stock-analysis-engine>`__ from using the same Kubernetes cluster. Additionally with the speed ae is moving, I am looking to keep trying new high availablity solutions and configurations to ensure the intraday data collection never dies (hopefully out of the box too!).

Deploy AE
---------

- `Configure AE <https://github.com/jay-johnson/metalnetes/blob/34c0eabf5f7007056a4823f5c4ea760aea7c8e6e/k8.env#L67-L89>`__

::

    ./deploy-ae.sh

Redeploying Using Helm
----------------------

#.  Find the Helm Chart to Remove (this example uses ``ae-grafana``):

    ::

        helm ls ae-grafana

#.  Delete and Purge the Helm Chart Deployment:

    ::

        helm delete --purge ae-grafana

#.  Deploy AE Helm Charts:

    ::

        ./ae/start.sh

Monitoring the Kubernetes Cluster
---------------------------------

.. note:: Grafana will only deploy if monitoring is enabled when running ``./deploy-ae.sh`` or if you run ``./ae/monitor-start.sh``.

Log in to Grafana from a browser:

- Username: **trex**
- Password: **123321**

https://grafana.example.com

Grafana comes ready-to-go with these starting dashboards:

View Kubernetes Pods in Grafana
-------------------------------

.. image:: https://i.imgur.com/GHo7dbd.png

View Rook Ceph Cluster in Grafana
----------------------------------

.. image:: https://i.imgur.com/wptrQW2.png

View Redis Cluster in Grafana
-----------------------------

.. image:: https://i.imgur.com/kegYzXZ.png

Uninstall AE
------------

::

    ./ae/_uninstall.sh

Please wait for the Persistent Volume Claims to be deleted

::

    kubetl get pvc -n ae

.. warning:: The Redis pvc ``redis-data-ae-redis-master-0`` must be manually deleted to prevent issues with redeployments after an uninstall
    ::

        kubectl -n ae delete pvc redis-data-ae-redis-master-0

Delete Cluster VMs
==================

::

    ./kvm/_uninstall.sh

License
=======

Apache 2.0 - Please refer to the `LICENSE <https://github.com/jay-johnson/metalnetes/blob/master/LICENSE>`__ for more details.

FAQ
===

What IP did my VMs get?
-----------------------

Find VMs by MAC address using the ``K8_VM_BRIDGE`` bridge device using:

::

    ./kvm/find-vms-on-bridge.sh

Find your MAC addresses with a tool that uses ``arp-scan`` to list all ip addresses on the configured bridge device (``K8_VM_BRIDGE``):

::

    ./kvm/list-bridge-ips.sh

Why Are Not All Rook Ceph Operators Starting?
---------------------------------------------

Restart the cluster if you see an error like this when looking at the ``rook-ceph-operator``:

::

    # find pods: kubectl get pods -n rook-ceph-system | grep operator
    kubectl -n rook-ceph-system describe po rook-ceph-operator-6765b594d7-j56mw

::

    Warning  FailedCreatePodSandBox  7m56s                   kubelet, m12.example.com  Failed create pod sandbox: rpc error: code = Unknown desc = failed to set up sandbox container "9ab1c663fc53f75fa4f0f79effbb244efa9842dd8257eb1c7dafe0c9bad1ee6c" network for pod "rook-ceph-operator-6765b594d7-j56mw": NetworkPlugin cni failed to set up pod "rook-ceph-operator-6765b594d7-j56mw_rook-ceph-system" network: failed to set bridge addr: "cni0" already has an IP address different from 10.244.2.1/24

::

    ./clean.sh
    ./deploy-rook-ceph.sh

Helm fails with connection refused
----------------------------------

If you see this:

::

    metalnetes$ helm ls
    Error: Get http://localhost:8080/api/v1/namespaces/kube-system/pods?labelSelector=app%3Dhelm%2Cname%3Dtiller: dial tcp 127.0.0.1:8080: connect: connection refused

Source the ``k8.env`` Cluster Config file:

::

    metalnetes$ source k8.env
    metalnetes$ helm ls
    NAME         	REVISION	UPDATED                 	STATUS  	CHART           	APP VERSION	NAMESPACE
    ae           	1       	Thu Mar 21 05:49:38 2019	DEPLOYED	ae-0.0.1        	0.0.1      	ae
    ae-grafana   	1       	Thu Mar 21 05:57:17 2019	DEPLOYED	grafana-2.2.0   	6.0.0      	ae
    ae-jupyter   	1       	Thu Mar 21 05:49:43 2019	DEPLOYED	ae-jupyter-0.0.1	0.0.1      	ae
    ae-minio     	1       	Thu Mar 21 05:49:40 2019	DEPLOYED	minio-2.4.7     	2019-02-12 	ae
    ae-prometheus	1       	Thu Mar 21 05:57:16 2019	DEPLOYED	prometheus-8.9.0	2.8.0      	ae
    ae-redis     	1       	Thu Mar 21 05:49:42 2019	DEPLOYED	redis-6.4.2     	4.0.14     	ae

Comparing Repo Example Files vs Yours
-------------------------------------

When starting a server from scratch, I like to compare notes from previous builds. I have uploaded the Fedora 29 server's files to help debug common initial installer-type issues. Let me know if you think another one should be added to help others. Please take a moment to compare your server's configured files after the install finishes by looking at the `fedora/etc directory <https://github.com/jay-johnson/metalnetes/tree/master/fedora/etc>`__ with structure and notes:

::

    tree fedora/etc/
    fedora/etc/
    ├── dnsmasq.conf # dnsmasq that was conflicting with named later (http://www.thekelleys.org.uk/dnsmasq/doc.html) - dnsqmasq was disabled and stopped on the server using systemctl
    ├── docker
    │   └── daemon.json # examples for setting up your private docker registry
    ├── named.conf
    ├── NetworkManager
    │   └── NetworkManager.conf # this is enabled and running using systemctl
    ├── resolv.conf # locked down with: sudo chattr +i /etc/resolv.conf
    ├── resolv.dnsmasq
    ├── ssh
    │   └── sshd_config # initial ssh config for logging in remotely as fast as possible - please lock this down after install finishes
    ├── sysconfig
    │   └── network-scripts
    │       ├── ifcfg-br0 # bridge network device - required for persisting through a reboot
    │       └── ifcfg-eno1 # server network device - required for persisting through a reboot
    └── var
        └── named
            └── example.com.zone # dns zone

How do I know when my VMs have an IP address?
---------------------------------------------

I use this bash alias in my ``~/.bashrc`` to monitor VMs on the ``br0`` device:

::

    showips() {
        watch -n1 'sudo arp-scan -q -l --interface br0 | sort'
    }

Then ``source ~/.bashrc`` and then run: ``showips`` to watch everything on the ``br0`` bridge networking device with each IP's MAC address. (Exit with ``ctrl + c``)

Manually Fix Fedora /etc/resolv.conf
------------------------------------

NetworkManager and dnsmasq had lots of conflicts initially. I used this method to **lock down** ``/etc/resolv.conf`` to ensure the dns routing was stable after reboots.

::

    sudo su
    nmcli connection modify eth0 ipv4.dns "192.168.0.100 8.8.8.8 8.8.4.4"
    vi /etc/resolv.conf
    chattr +i /etc/resolv.conf
    systemctl restart NetworkManager
