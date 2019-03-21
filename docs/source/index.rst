.. Metalnetes documentation master file, created by
   sphinx-quickstart on Fri Sep 14 19:53:05 2018.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Metalnetes
==========

Tools for managing multiple kubernetes **1.13.4** clusters on KVM (3 Centos 7 vms) running on a bare metal server (tested on Ubuntu 18.04).

.. image:: https://i.imgur.com/8uvAcgF.png

This will install:

- Kubernetes cluster deployed 3 CentOS 7 VMs using 100 GB with static IPs and installed using KVM
- Rook Ceph Storage Cluster for Persistent Volumes
- Grafana + Prometheus
- Optional - Stock Analysis Engine that includes:
    - Minio (on-premise S3)
    - Redis cluster
    - Jupyter
- SSH access

Getting Started
---------------

::

    git clone https://github.com/jay-johnson/metalnetes.git metalnetes
    cd metalnetes

Start VMs and Kubernetes Cluster
--------------------------------

::

    ./boot.sh

View Kubernetes Nodes
---------------------

::

    ./tools/show-nodes.sh

Monitoring the Kubernetes Cluster
=================================

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

Changing Between Kubernetes Clusters
====================================

If you create new ``k8.env`` files for each cluster, like ``dev_k8.env`` and ``prod_k8.env`` then you can then quickly toggle between clusters using:

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

Customize VMs and Manage Kubernetes Deployments
===============================================

These are the steps the automated ``./boot.sh`` runs in order for customizing and debugging your kubernetes deployment.

Create VMs Using KVM on Ubuntu
==============================

#.  Install `KVM <https://help.ubuntu.com/community/KVM/Installation>`__ and `arp-scan <https://github.com/royhills/arp-scan>`__ to find each VM's ip address

    This guide was written using an Ubuntu bare metal server, but it is just KVM under the hood. Please feel free to open a PR if you know the commands for CentOS, Fedora or RHEL and I will add them.

    ::

        cd kvm
        sudo ./install-kvm.sh

#.  Start VMs

    This will create 3 vms by default and uses an `internal fork from the giovtorres/kvm-install-vm script <https://github.com/giovtorres/kvm-install-vm/blob/master/kvm-install-vm>`__. To provision vm disks using ``qemu-img``, this tool will prompt for ``root`` access when needed.

    ::

        ./start-cluster-vms.sh

#.  Assign IPs to Router or DNS server

    This tool uses ``arp-scan`` to find all active ip addresses on the network bridge. With this list, the tool then looks up each vm's ip by the MAC address, and it requires ``root`` privileges.

    ::

        ./find-vms-on-bridge.sh

    Alternatively you can set ``/etc/hosts`` too:

    ::

        192.168.0.110   m10 m10.example.com master10.example.com
        192.168.0.111   m11 m11.example.com master11.example.com
        192.168.0.112   m12 m12.example.com master12.example.com

#.  Bootstap Nodes

    Once the vm's are routable by their fqdn (e.g. ``m10.example.com``), you can use the bootstrap tool to start preparing the cluster nodes, confirm ssh access works with all nodes.

    ::

        ./bootstrap-new-vms.sh

Install Kubernetes on CentOS 7
==============================

Configuration
-------------

Now that the VMs are ready you can use the `k8.env CLUSTER_CONFIG example file <https://github.com/jay-johnson/metalnetes/tree/master/k8.env>`__ for managing kubernetes clusters on your own vms. This step becomes the starting point for start, restarting and managing clusters.

::

    cd ..
    ./install-centos-vms.sh

VM and Kubernetes Node Configuration
------------------------------------

- `VM names, Cluster Nodes, Node Labels, Cluster Tools section <https://github.com/jay-johnson/metalnetes/blob/b6b75e4be277c11ca510712e60649f171ff4551f/k8.env#L129-L227>`__

Helm and Tiller Configuration
-----------------------------

- `Helm and Tiller <https://github.com/jay-johnson/metalnetes/blob/b6b75e4be277c11ca510712e60649f171ff4551f/k8.env#L81-L88>`__

Cluster Storage Configuation
----------------------------

- `Storage (rook-ceph by default) <https://github.com/jay-johnson/metalnetes/blob/b6b75e4be277c11ca510712e60649f171ff4551f/k8.env#L90-L98>`__
- `Additional Block Devices per VM <https://github.com/jay-johnson/metalnetes/blob/b6b75e4be277c11ca510712e60649f171ff4551f/k8.env#L211-L221>`__

Private Docker Registry
-----------------------

- `Registry <https://github.com/jay-johnson/metalnetes/blob/b6b75e4be277c11ca510712e60649f171ff4551f/k8.env#L68-L79>`__

Start Kubernetes Cluster
========================

With 3 vms setup using the `install-centos-vms.sh <https://github.com/jay-johnson/metalnetes/tree/master/install-centos-vms.sh>`__ follow these steps to stand up and tear down a kubernetes cluster.

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

If you want to reboot vms and have the nodes re-join and rebuild the kubernetes cluster use:

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

This repository was created after trying to decouple my `AI kubernetes cluster for analyzing network traffic <https://github.com/jay-johnson/deploy-to-kubernetes>`__ and my `Stock Analysis Engine (ae) that uses many deep neural networks to predict future stock prices during live-trading hours <https://github.com/AlgoTraders/stock-analysis-engine>`__ from using the same kubernetes cluster. Additionally with the speed ae is moving, I am looking to keep trying new high availablity solutions and configurations to ensure the intraday data collection never dies (hopefully out of the box too!).

Deploy AE
---------

- `Configure AE <https://github.com/jay-johnson/metalnetes/blob/b6b75e4be277c11ca510712e60649f171ff4551f/k8.env#L100-L122>`__

::

    ./deploy-ae.sh

Delete Cluster VMs
==================

::

    ./kvm/_uninstall.sh

Background and Notes
====================

Customize the vm install steps done during boot up using the `cloud-init-script.sh <https://github.com/jay-johnson/metalnetes/tree/master/install-centos-vms.sh>`__.

License
=======

Apache 2.0 - Please refer to the `LICENSE <https://github.com/jay-johnson/metalnetes/blob/master/LICENSE>`__ for more details.

FAQ
===

What IP did my vms get?
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

Table of Contents
=================

.. toctree::
   :maxdepth: 2
   :caption: Contents:

Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`
