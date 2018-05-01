20180427

Set up an openshift cluster on 3 beaker hosts at Red Hat.
This is only useful if you can get to the Red Hat lab machines,
however, the approach may be useful elsewhere.

This is time dated. Things move quickly with Openshift.

-------------

Install Openshift v3 on Lab Hardware

Overview:
This describes how to set up an OCP (Openshift V3) cluster using a OCP
development Puddle on bare metal lab machines. It modifies the cluster
to permit Openshift/origin development and debug.

This installs Fedora 27 and OCP 3.10 development puddles.


The steps are:

-  Provision the hosts/nodes using beaker
-  Customize for cluster needs
-  Set up Docker persistent storage
-  Install Docker
-  Setup an OCP Development Puddle
-  Customize ansible and Install the cluster
-  Customize the installed cluster for software development.


The general flow is to acquire hosts for the cluster from beaker and
install a recent Fedora Server (not Client) image on the hosts. Next
install needed packages and configure storage and networking for the
cluster. This setup provides the needed environment to install Docker
and Openshift. Add the puddle repo and install ansible. Customize the
host file for the cluster and install Openshift. Verify the cluster
came up properly. Configure the default registry which will store your
docker images. Clone origin build and customize the cluster to operate
using the built components.

The Openshift documentation is used as a basis. There is additional
material covering items not found in the documentation.

The rest of this goes into the details of setting up a 3 node cluster
on bare metal beaker lab hosts.


Lab Machines and Beaker:

Reserve the hosts for the cluster and provision them with a suitable system.

Set up 3 beaker machines to be a 3 node cluster:
netdev22 wsfd-netdev22.ntdv.lab.eng.bos.redhat.com 10.19.188.9 (master)
netdev28 wsfd-netdev28.ntdv.lab.eng.bos.redhat.com 10.19.188.22
netdev35 wsfd-netdev35.ntdv.lab.eng.bos.redhat.com 10.19.188.36

Of the three hosts, netdev22 will be the master and a node, the
others are nodes.

In this case the hosts have network HW that permits an internal 10Ge
cluster network and separate 10Ge network for NFS file storage. The
lab network is 1Ge and is used to access the cluster. None of this
network setup is required, however since the HW is available, why not
use it?

The nodes are Dell R730 servers with 2 1Ge NICs and 2 10Ge NICs and
a 1T disk. The NICs are used as follows:

eno1 10ge 10.253.0.x nfs mount common data store, openshift registry
eno2 10ge 10.253.1.x internal cluster networking
eno3 1ge 10.19.188.x lab net interface
eno4 1 Ge - not used


The disk on netdev22 is split into a NFS store for the Openshift
default registry and Docker persistent storage. The other two nodes
have a large docker persistent storage area. Note, images are around
1Gb each.

The beaker hosts are provisioned with Fedora-27 Server


LAPTOP Ease of Use Changes:

It is convenient to directly access the cluster nodes. Toward that
end the .bashrc and /etc/hosts can be extended.

~/.bashrc

# Add aliases for beaker hosts
alias netdev22='ssh -X root@netdev22a'
alias netdev28='ssh -X root@netdev28a'
alias netdev35='ssh -X root@netdev35a'


/etc/hosts

# add lines for the lab machines:
# netdev22a is master and node, rest are nodes
10.19.188.9 netdev22a
10.19.188.22 netdev28a
10.19.188.36 netdev35a


ssh access without passwords is also convenient. To do this use ssh-keygen
to create a RSA key and share the public key with beaker. When beaker
provisions the hosts it will copy in your public key and set the root
password from your beaker profile.


Provision The Hosts:

Beaker help

https://beaker.engineering.redhat.com/

Beaker home page. Login.


First Time Setup:

Go to:

https://beaker.engineering.redhat.com/prefs/#root-password
In prefs, set root PW and save a SSH Public Key.


The installed hosts will have this root password and your public rsa
key so you can ssh to root@<host> without a password


Select The Hosts:

https://beaker.engineering.redhat.com/mine

Either assign systems from the desired pool or select previously reserved
systems from "My Systems" in the
"Hello, <my-name>" tab.

To get more systems:
https://beaker.engineering.redhat.com/
Systems->all
"Show Search Options" box: enter netdev
click on a system with no "User"
Don't forget to "take" the loan.


Provision Systems Using Beaker:

Provision each host in turn with the same system image. This example uses Fedora-27 Server


Click on the system name, then press provision (on left side)
https://beaker.engineering.redhat.com/view/wsfd-netdev22.ntdv.lab.eng.bos.redhat.com#provision
https://beaker.engineering.redhat.com/view/wsfd-netdev28.ntdv.lab.eng.bos.redhat.com#provision
https://beaker.engineering.redhat.com/view/wsfd-netdev35.ntdv.lab.eng.bos.redhat.com#provision


Distro:
Family: Fedora27
Tag: None selected
Distro: Fedora27
DistroTree: Fedora27 Server x86_64


Press PROVISION


This is installing a current DistroTree: Fedora-27. There are a limited
number of snapshots on beaker at any point in time and at some point this
version will be deleted. When this happens or when you want a more recent
snapshot, edit the beaker files in /etc/yum.repos.d, just grep for
Fedora-27 and edit the new version from
http://download.eng.bos.redhat.com/nightly/
on all the files it exists each host. After that do a yum update on each host.


There is no notification when provisioning completes. You can monitor
the console on each host for completion.


Console access is done as follows:

# console wsfd-netdev22.ntdv.lab.eng.bos.redhat.com#

[Enter `^Ec?' for help]
[-- MOTD -- https://home.corp.redhat.com/wiki/conserver]
^Ec. ---disconnect



Provisioning ends when the the login: line appears. At this point ssh
will work.


Login as root with your root password (from above)
# cat /etc/redhat-release
to see installed version.


Login from your laptop to verify access:

# ssh to root@<hostname>

=================================================
System Post Install - Before the Openshift Install

The Openshift documentation provides details on installing the cluster.
There are additional things to do before the items documented in the
Openshift installation docs. See:

Host Preparation - Installing a Cluster | Installation and Configuration
| OpenShift Container Platform 3.10


There are several post install changes that need to be made before
installing the OCP puddle.

Since the disks on the lab machines are not used for much most of the
space can be reserved for the docker persistent storage. In addition,
Openshift (OCP) includes a default registry for storing docker images
for the cluster. This registry is used in development to store development
built containers for deployment in the cluster for debug and test.


The OCP registry can be placed on any host in the cluster. In this example
it is on master. So the disk on master is shared between the OCP registry
and Docker persistent storage.

Fedora-27 uses LVM to manage the disk. There are root, and swap logical
volumes that consume a small portion of the disk.

netdev22 (the master) will end up with the openshift registry and nfs
storage for built objects.

For this reason the root (/) ie extended to use the rest of the 1-T disk
on all three hosts.

# lvs
LV   VG  Attr LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
root fedora_wsfd-netdev22 -wi-ao---- 15.00g
swap fedora_wsfd-netdev22 -wi-ao----  4.00g

Modify the lvm configuration
# lvextend --size +870G /dev/mapper/fedora_wsfd--netdev22-root
  Size of logical volume fedora_wsfd-netdev22/root changed from 15.00 GiB (3840 extents) to 885.00 GiB (226560 extents).
  Logical volume fedora_wsfd-netdev22/root successfully resized.
# xfs_growfs /
# df -h /
Filesystem                              Size  Used Avail Use% Mounted on
/dev/mapper/fedora_wsfd--netdev22-root  885G  1.9G  884G   1% /

Do the above on all three hosts

Ansible:

Use ansible on your laptop to configure the hosts. There is a lot of
setup that is much easier using an inventory file containing the hosts
and playbooks.

Ansible requires python on all hosts and python is not part of
Fedora Server, so explicitly install it on each host.
First install python on each host:
# ssh root@netdev22a dnf install -y python
# ssh root@netdev28a dnf install -y python
# ssh root@netdev35a dnf install -y python

Create the hosts file and hostsplay.yaml files.
The hosts file contains the inventory of all of the hosts
in the cluster and hostsplay.yaml is the playbook to install and set
up the hosts to be part of the future cluster. 

Install packages
./hostsrun pkg

================================================================
Customize networking on the hosts:
eno1 10.253.0.xx is for nfs mounts
eno2 10.253.1.xx is for cluster internal networking


On netdev22
# cd /etc/sysconfig/network-scripts/

# cat ifcfg-eno1
BOOTPROTO=none
IPADDR="10.253.0.22"
NETMASK="255.255.255.0"
#BOOTPROTO=dhcp
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno1
UUID=997704ee-6955-358a-b515-5019945845c3
ONBOOT=yes
AUTOCONNECT_PRIORITY=-999
DEVICE=eno1

# cat ifcfg-eno2
BOOTPROTO="none" <----
IPADDR="10.253.1.22" <----
NETMASK="255.255.255.0" <----
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
#BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=eno2
UUID=f5a5e080-923d-3cfa-934e-038a29e9a5bd
ONBOOT=yes
AUTOCONNECT_PRIORITY=-999
DEVICE=eno2

# ifup eno1
# ifup eno2

 On netdev28:
# cd /etc/sysconfig/network-scripts/

# cat ifcfg-eno1
BOOTPROTO="none" <-----
IPADDR="10.253.0.28" <-----
NETMASK="255.255.255.0" <-----
ONBOOT=yes

# cat ifcfg-eno2
BOOTPROTO="none"
IPADDR="10.253.1.28"
NETMASK="255.255.255.0"
ONBOOT=yes <-----

# ifup eno1
# ifup eno2


On netdev35:
# cd /etc/sysconfig/network-scripts/

# cat ifcfg-eno1
BOOTPROTO="none" <-----
IPADDR="10.253.0.35" <-----
NETMASK="255.255.255.0" <-----
ONBOOT=yes

# cat ifcfg-eno2
BOOTPROTO="none"
IPADDR="10.253.1.35"
NETMASK="255.255.255.0"
ONBOOT=yes <-----

# ifup eno1
# ifup eno2

On all nodes add these lines to the /etc/hosts file:

# labnet
10.19.17.9 netdev22
10.19.17.22 netdev28
10.19.17.36 netdev35
# eno1 net
10.253.0.22 netdev22b
10.253.0.28 netdev28b
10.253.0.35 netdev35b
# eno2 net
10.253.1.22 netdev22a
10.253.1.28 netdev28a
10.253.1.35 netdev35a


At this point you can ping over all the networks.

================================================================
Set Up Key Exchange on All Nodes
Ansible uses ssh for everything and since we will be running ansible
from the master (netdev22) we need to set up shared keys between
netdev22 and the other nodes. For completeness, we set up keys on
all the nodes.

ssh-keygen will create a public/private key pair for a host.

Press <enter> at all prompts
# ssh-keygen

Now copy the public key to each node and ssh to each interface.
# ssh-copy-id netdev22
# ssh netdev22
# ssh netdev22a
# ssh netdev22b
# ssh-copy-id netdev28
# ssh netdev28
# ssh netdev28a
# ssh netdev28b
# ssh-copy-id netdev35
# ssh netdev35
# ssh netdev35a
# ssh netdev35b

At his point you can ssh to any node from any node over all NICs without passwords.


================================================================

Set Up NFS

Nfs is used by the Openshift default Docker Registry and during development
to share built excutables. All of this is described in later sections. At
this point we just set up nfs.

NOTE: There are no security concerns since this is a lab cluster.

Nfs is set up on master since no pods will run there.

# ./hostsrun nfs


================================================================
Configure and restart docker

./hostsrun docker

================================================================

