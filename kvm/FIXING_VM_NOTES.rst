Work in Progress - Fixing VMs
=============================

This is a work in progress and was created before the migration to https://github.com/giovtorres/kvm-install-vm/blob/master/kvm-install-vm - These commands will work, but definitely are not 100% stable. Use at your own risk.

Please, shutdown the broken vms before running these steps.

Mount the broken vm disks on another running vm with:

::

    virsh detach-disk m4 /data/kvm/disks/m4.qcow2
    virsh detach-disk m5 /data/kvm/disks/m5.qcow2
    virsh detach-disk m6 /data/kvm/disks/m6.qcow2
    virsh attach-disk c1 --target vdd --subdriver qcow2 /data/kvm/disks/m4.qcow2
    virsh attach-disk c1 --target vde --subdriver qcow2 /data/kvm/disks/m5.qcow2
    virsh attach-disk c1 --target vdf --subdriver qcow2 /data/kvm/disks/m6.qcow2

Once all the disks are mounted, show the volume groups:

::

    vgdisplay

Rename any duplicates, ``centos`` may be duplicated so just append a number suffix like:

::

    vgrename aCWiwn-y8cA-YGds-GGgS-PxoF-ChWS-xwHIMv centos1
    vgrename qkG8iM-DRZX-Hwgh-Maaf-201I-7Ah1-1NNSDg centos2
    vgrename su4jol-w4uJ-x3FR-gKjM-lIp2-k7It-JdpIfd centos3

Run these steps:

::

    modprobe dm-mod
    vgchange -ay
    lvscan

Mount and fix broken files:

::

    mkdir -p -m 777 /mnt/test/{m4,m5,m6}
    mkdir -p -m 777 /mnt/test/{b4,b5,b6}
    mkdir -p -m 777 /mnt/test/{s4,s5,s6}

::

    mount /dev/vdj1 /mnt/test/b4
    mount /dev/vdk1 /mnt/test/b5
    mount /dev/vdl1 /mnt/test/b6
    mount /dev/mapper/centos1-root /mnt/test/m4
    mount /dev/mapper/centos2-root /mnt/test/m5
    mount /dev/mapper/centos3-root /mnt/test/m6
    mount /dev/mapper/centos1-swap /mnt/test/s4
    mount /dev/mapper/centos2-swap /mnt/test/s5
    mount /dev/mapper/centos3-swap /mnt/test/s6

::

    vi /mnt/test/m4/etc/fstab
    vi /mnt/test/m5/etc/fstab
    vi /mnt/test/m6/etc/fstab
    vi /mnt/test/b4/grub2/grub.cfg
    vi /mnt/test/b5/grub2/grub.cfg
    vi /mnt/test/b6/grub2/grub.cfg

::

    umount /mnt/test/m4
    umount /mnt/test/s4
    umount /mnt/test/b4
    umount /mnt/test/m5
    umount /mnt/test/s5
    umount /mnt/test/b5
    umount /mnt/test/m6
    umount /mnt/test/s6
    umount /mnt/test/b6

Detach all disks from the vm:

::

    virsh detach-disk

::

    virsh detach-disk c1 /data/kvm/disks/m4.qcow2
    virsh detach-disk c1 /data/kvm/disks/m5.qcow2
    virsh detach-disk c1 /data/kvm/disks/m6.qcow2
    virsh attach-disk m4 --target vda --subdriver qcow2 /data/kvm/disks/m4.qcow2
    virsh attach-disk m5 --target vda --subdriver qcow2 /data/kvm/disks/m5.qcow2
    virsh attach-disk m6 --target vda --subdriver qcow2 /data/kvm/disks/m6.qcow2
