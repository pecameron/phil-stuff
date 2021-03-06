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

This installs Fedora 28 and OCP 3.10 development puddles.
OCP 3.10 uses daemonsets, instead of systemctl, to run the cluster.

This doc describes a simple 3 node install that uses the lab network
for networking.

The development host is another beaker machine because docker gets 
bogged down on the cluster machines. Also, local registry on the 
build machine serves the images.


The steps are:

-  Provision the hosts/nodes using beaker
-  Customize for cluster needs
-  Set up lvm space for Docker persistent storage
-  Install Docker
-  Setup an OCP Development Puddle
-  Customize ansible and Install the cluster
-  Customize the installed cluster for software development.

The general flow is to acquire hosts for the cluster from beaker and
install a recent Fedora Server (not Client) image on the hosts.
Server allocats a small /root and leaves the rest of the disk alone.
Later steps expand /root while leaving room for the docker thinpool.

Next install needed packages and configure storage and networking for the
cluster. This setup provides the needed environment to install Docker
and Openshift.

Add the OCP 3.10 puddle repo and install openshift-ansible. This is
the collection of ansible playbooks and roles that install Openshift.

Customize the host file for the cluster and install Openshift. Verify
the cluster came up properly.

Configure the default registry which will store your docker images.
Clone origin build and customize the cluster to operate using the
built components.

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

Beaker machine for development environment is netdev31

Of the three hosts, netdev22 will be the master and a node, the
others are nodes.

The nodes are Dell R730 servers with 2 1Ge NICs and 2 10Ge NICs and
a 1T disk. The NICs are used as follows:

eno1 10ge - not used
eno2 10ge - not used
eno3 1ge 10.19.188.x lab net interface
eno4 1 Ge - not used


The disk on netdev22 is split into a space for the Openshift
default registry and Docker persistent storage. The other two nodes
have a large docker persistent storage area. Note, images are around
1Gb each.


LAPTOP Ease of Use Changes:

It is convenient to directly access the cluster nodes. Toward that
end the .bashrc and /etc/hosts can be extended.

~/.bashrc

# Add aliases for beaker hosts
alias netdev22='ssh -X root@netdev22a'
alias netdev28='ssh -X root@netdev28a'
alias netdev35='ssh -X root@netdev35a'


===========================
On laptop edit /etc/hosts

# add lines for the lab machines:
# netdev22a is master and node, rest are nodes
10.19.188.9 netdev22a
10.19.188.22 netdev28a
10.19.188.36 netdev35a


==========================
ssh access from the laptop to the beaker hosts without passwords is also
convenient. To do this use ssh-keygen to create a RSA key and share the
public key with beaker. When beaker provisions the hosts it will copy in
your public key and set the root password from your beaker profile.


On beaker, Provision The Hosts:

Beaker help

https://beaker.engineering.redhat.com/

Beaker home page. Login.


First Time Setup:

Go to:

https://beaker.engineering.redhat.com/prefs/#root-password
In prefs, set root PW and save a SSH Public Key.


The installed hosts will have this root password and your public rsa
key so you can ssh to root@<host> without a password


==========================
On beaker, Select The Hosts:

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


==========================
Provision Systems Using Beaker:

Provision each host in turn with the same system image. This example uses Fedora-28 Server.


Click on the system name, then press provision (on left side).
Repeat for all three hosts.
https://beaker.engineering.redhat.com/view/wsfd-netdev22.ntdv.lab.eng.bos.redhat.com#provision
https://beaker.engineering.redhat.com/view/wsfd-netdev28.ntdv.lab.eng.bos.redhat.com#provision
https://beaker.engineering.redhat.com/view/wsfd-netdev35.ntdv.lab.eng.bos.redhat.com#provision


Distro:
Family: Fedora28
Tag: None selected
Distro: Fedora28
DistroTree: Fedora28 Server x86_64


Press PROVISION


This is installing a current DistroTree: Fedora-28. There are a limited
number of snapshots on beaker at any point in time and at some point this
version will be deleted. When this happens or when you want a more recent
snapshot, edit the beaker files in /etc/yum.repos.d, just grep for
Fedora-28 and edit the new version from
http://download.eng.bos.redhat.com/nightly/
On each host, edit all the /etc/yum.repos.d/ files that mention the image.
After that do a yum update on each host.


There is no notification when provisioning completes. You can monitor
the console on each host for completion.

===========================
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
=================================================
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

The 3 selected hosts netdev22,28, and 35 have 1-Tb disks. 

The OCP registry can be placed on any host in the cluster. In this example
it is on master. So the disk on master is shared between the OCP registry
and Docker persistent storage.

Fedora-28 uses LVM to manage the disk. There are root, and swap logical
volumes that consume a small portion of the disk.

netdev22 (the master) will end up with the openshift registry and nfs
storage for built objects.

For this reason the root (/) ie extended to use half of the 1-T disk
on all three hosts. This is done on each host (no ansible).

# lvs
LV   VG  Attr LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
root fedora_wsfd-netdev22 -wi-ao---- 15.00g
swap fedora_wsfd-netdev22 -wi-ao----  4.00g

Modify the lvm configuration
# lvextend --size +500G /dev/mapper/fedora_wsfd--netdev22-root
  Size of logical volume fedora_wsfd-netdev22/root changed from 15.00 GiB (3840 extents) to 515.00 GiB (131840 extents).
  Logical volume fedora_wsfd-netdev22/root successfully resized.
# xfs_growfs /
# df -h /
Filesystem                              Size  Used Avail Use% Mounted on
/dev/mapper/fedora_wsfd--netdev22-root  515G  1.6G  514G   1% /

Do the above on all three hosts

=============================
Ansible:

Use ansible on your laptop to configure the hosts. There is a lot of
setup that is much easier using an inventory file containing the hosts
and playbooks.

Ansible requires python on all hosts and python is not part of
Fedora Server, so explicitly install it on each host.
First install python on each host:
# ssh root@netdev22a dnf install -y python libselinux-python
# ssh root@netdev28a dnf install -y python libselinux-python
# ssh root@netdev35a dnf install -y python libselinux-python

Create the hosts file and hostsplay.yaml files.
The hosts file contains the inventory of all of the hosts
in the cluster and hostsplay.yaml is the playbook to install and set
up the hosts to be part of the future cluster. 

====== Notes ======
The puddle is configured in 
files/openshift_additional.repo

Next install the puddle and verify proper operation of the cluster
before continuing.

Notifications about the availability of new puddles arrive in email.
For this example we will use a 3.10 build, New AtomicOpenShift-3.10 Puddle: latest

http://download.lab.bos.redhat.com/rcm-guest/puddles/RHAOS/AtomicOpenShift/3.10/latest

The automated development builds create puddles that can be installed to
work with specific versions of openshift.

The puddles are found in:
http://download-node-02.eng.bos.redhat.com/rcm-guest/puddles/RHAOS/AtomicOpenShift/
Index of /rcm-guest/puddles/RHAOS/AtomicOpenShift
Name Last modified Size Description
Parent Directory -
3.1/  01-May-2017 16:57 -
3.2/  20-Apr-2017 10:59 -
3.3/  02-May-2017 06:45 -
3.4/  02-May-2017 09:13 -
3.5/  02-May-2017 11:43 -
3.6/  01-May-2017 23:25 -
3.7/  12-Apr-2018 04:42 -   
3.8/  11-Apr-2018 03:14 -   
3.9/  27-Apr-2018 13:00 -   
3.10/ 01-May-2018 13:21 - 

The container images are found in
brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888
with the expected image names tagged with the version v3.10.1,
or similar. The image repository is set up in a later step.
===================

Install packages
./hostsrun pkg

================================================================
========== may not need this  =================

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
# ssh-copy-id netdev28
# ssh netdev28
# ssh-copy-id netdev35
# ssh netdev35

At his point you can ssh to any node from any node over all NICs without passwords.


================================================================
Configure and restart docker

Docker storage is not set up. This results in docker using a file
for storage.

./hostsrun docker

If docker doesn't start due to:
Error starting daemon: error initializing graphdriver: devmapper: Unable to take
Try resetting docker storage:
- # rm -rf /var/lib/docker
- # docker-storage-setup --reset
- # docker-storage-setup

================================================================
=================== MAY NOT NEED THIS ====================

Install openshift-ansible on the laptop

On the laptop, copy the OCP repo to /etc/yum.repos.d/openshift_additional.repo
$ sudo cp files/openshift_additional.repo /etc/yum.repos.d/openshift_additional.repo

On the laptop install openshift-ansible
$ sudo dnf install -y openshift-ansible

On laptop:
# rpm -qa | grep openshift-a
openshift-ansible-docs-3.10.0-0.32.0.git.0.bb50d68.el7.noarch
openshift-ansible-playbooks-3.10.0-0.32.0.git.0.bb50d68.el7.noarch
openshift-ansible-3.10.0-0.32.0.git.0.bb50d68.el7.noarch
openshift-ansible-roles-3.10.0-0.32.0.git.0.bb50d68.el7.noarch

Note: 3.10.0-0.32 or newer is required.

================================================================
Some additional items:

===== not needed on fresh install ====
Disable iptables - (may already be disabled)
The Openshift Ansible, in a later step, installs the needed iptables rules.
At this point make sure iptables is disabled on all nodes. Since this is
a lab configuration for test purposes there is little security concern.

On each host (may not be needed):
# systemctl stop iptables
# systemctl disable iptables
=======================================


================================================================

Installing Openshift v3 (OCP 3.10)

$ ./hostsrun prereqs

./osehosts is the hosts file for installing OCP. cni is set,
however ovs and sdn get installed anyway.
os_sdn_network_plugin_name='cni'

$ ./hostsrun cluster

The cluster install fails trying to install the web_console.

NOTE: 3.10 
ovs and sdn are always installed.

$ ssh root@netdev22
# oc project openshift-sdn
# oc delete ds sdn
# oc delete ds ovs

More cleanup may be needed...
NOTE: 3.10

Uninstall the OCP cluster (leave the rest of the setup alone)

$ ./hostsrun uninstall


When this completes "ssh root@netdev22a" and verify that the nodes are present:
# oc get nodes
NAME                                        STATUS     ROLES           AGE       VERSION
wsfd-netdev22.ntdv.lab.eng.bos.redhat.com   NotReady   infra,master    29m       v1.10.0+b81c8f8
wsfd-netdev28.ntdv.lab.eng.bos.redhat.com   NotReady   compute,infra   26m       v1.10.0+b81c8f8
wsfd-netdev35.ntdv.lab.eng.bos.redhat.com   NotReady   compute,infra   26m       v1.10.0+b81c8f8

On to setting up the network:

================================================================
============== ovnpre.yml ==========
OVN - ovn

This needs to be done on each node.
  - name: iptables 6641
    shell: iptables -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 6641 -j ACCEPT
  - name: iptables 6642
    shell: iptables -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 6642 -j ACCEPT

  - name: Ensure GENEVE's UDP port isn't firewalled
    shell: /usr/share/openvswitch/scripts/ovs-ctl --protocol=udp --dport=6081 enable-protocol

$ ./hostsrun ovnpre

================================================================

Because the needed images are in the puddle and not in default locations
the pods don't start.


# oc get po
NAME READY STATUS RESTARTS AGE
docker-registry-1-deploy 0/1 Pending 0 17m
registry-console-1-deploy 0/1 ContainerCreating 0 17m
router-1-deploy 0/1 Pending 0 18m



docker-registry doesn't start because netdev22 is region=infra and it is not scheduable. Edit the dc and change the nodeSelector.region to primary.
# oc edit dc/docker-registry
...
nodeSelector:
region: primary
...



Also in the dc/docker-registry, the default router image is not found since we need the one in the puddle:
image: registry.access.redhat.com/openshift3/ose-haproxy-router:v3.6.61



The Image from puddle is:
image: brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/openshift3/ose-haproxy-router:v3.6.61



After Verification:
# atomic-openshift-excluder exclude



The cluster is now installed.

================================================================
REST IS WIP
================================================================


Post Install
Firewalld
Firewalld is set up by ansible. Additional rules are needed for nfs and operation on the additional networks

Set up firewalld rules for nfs (port 2049) and eno1,eno2 networks on all hosts.



# firewall-cmd --list-all
# firewall-cmd --zone=public --add-port=2049/tcp --permanent
# firewall-cmd --zone=public --add-port=8443/tcp --permanent
# firewall-cmd --zone=public --add-port=8444/tcp --permanent
# firewall-cmd --zone=public --add-port=4001/tcp --permanent
# firewall-cmd --zone=public --add-port=9090/tcp --permanent
# firewall-cmd --zone=public --add-port=8053/udp --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
public (active)
target: default
icmp-block-inversion: no
interfaces: eno3
services: ssh dhcpv6-client
ports: 10250/tcp 80/tcp 443/tcp 4789/udp 2049/tcp
protocols:
masquerade: no
forward-ports:
source-ports:
icmp-blocks:
rich rules:


Fixup Image Configuration
There are some changes needed to correctly find the images.



On master edit imageConfig to latest
/etc/origin/master/master-config.yaml
...
imageConfig:
format: brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/openshift3/ose-${component}:latest
....



On each node edit imageConfig to latest
/etc/origin/node/node-config.yaml
...
imageConfig:
format: brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/openshift3/ose-${component}:latest
...



Fixup Image Configuration in Docker
The puddle images are in:
brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888
Verify that Ansible has properly configured docker and docker-registry.



On each node:
# vi /etc/sysconfig/docker
...
ADD_REGISTRY='--add-registry brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888 <rest of line>'
...
INSECURE_REGISTRY='--insecure-registry brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888 <rest of line>'
...
If changes were needed run:
# systemctl daemon-reload
# systemctl restart docker



Install Cluster Docker Registry Persistent Storage
The docker registry is installed by Ansible. Pods that you create that are to run on the cluster are pushed to the default docker-registry. By default registry storage is temporary and is lost when the registry pod is restarted. In an earlier step we reserved room for a persistent docker registry. Here is how to set it up.



By default the docker registry volume is not set up.

# oc get dc/docker-registry -o yaml

...
volumes:
- emptyDir: {}
name: registry-storage

...



Set up the persistent volume:

# oc volume deploymentconfigs/docker-registry \
--add --overwrite --name=registry-storage --mount-path=/registry \
--source='{"nfs": { "server": "10.253.0.22", "path": "/home/registry"}}'
The docker registry is accessed via the service:

# oc get svc docker-registry
NAME CLUSTER-IP EXTERNAL-IP PORT(S) AGE
docker-registry 172.30.138.33 <none> 5000/TCP 21h



Add the registry service account to the list of users allowed to run privileged containers:
# oc edit scc privileged
Add a lines under users with the user name
system:serviceaccount:default:registry.
system:serviceaccount:default:router



Restart the registry:
# oc deploy --latest dc/docker-registry
# oc get po -o wide
NAME READY STATUS RESTARTS AGE IP NODE
docker-registry-4-zj5hb 1/1 Running 0 14m 10.130.0.6 netdev28a
registry-console-1-nxhtw 0/1 CrashLoopBackOff 924 3d 10.130.0.3 netdev28a



On netdev28, get the docker container ID
# docker ps
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
28ad931e8005 brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/openshift3/ose-docker-registry@sha256:54e15633ab54592825a8b01569aca7340e33b2f811ffd6ea4f171f9fef391660 "/bin/sh -c 'DOCKER_R" 2 minutes ago Up 2 minutes k8s_registry_docker-registry-4-zj5hb_default_674790
look at the registry
# docker exec -it 28ad931e8005 find /registry
/registry
/registry/phil28
/registry/phil35



Bring up router
Delete the (non working) router
# oc delete dc/router



Create a new router:
# oadm router --replicas=1 \
--images=brew-pulp-docker01.web.prod.ext.phx2.redhat.com:8888/openshift3/ose-haproxy-router:latest



Verify it came up

# oc get po -o wide



Accessing the Cluster Docker Registry
To access the registry directly, such as to perform docker push or docker pull operations, you must first log in to the registry using an access token.



Ensure you are logged in to OpenShift as a regular user (system:admin doesn't have a token):
# oc login -u root



Get your access token:
# oc whoami -t

<token>



oc get svc
# oc get svc docker-registry
NAME CLUSTER-IP EXTERNAL-IP PORT(S) AGE
docker-registry 172.30.138.33 <none> 5000/TCP 1d



Log in to the Docker registry on each node using same token
# docker login -u admin -p <token> 172.30.138.33:5000

You can now tag built docker images with the repository:

# docker tag openshift/origin-haproxy-router-dev 172.30.138.33:5000/openshift/origin-haproxy-router-dev



And push them to the registry:

# docker push 172.30.138.33:5000/openshift/origin-haproxy-router-dev



You may need to login to docker from time to time.



Add the docker-repository to the Docker Configuration
Get the address of the docker-registry service:# oc get svc docker-registry
NAME CLUSTER-IP EXTERNAL-IP PORT(S) AGE
docker-registry 172.30.138.33 <none> 5000/TCP 1d



On each node:
# vi /etc/sysconfig/docker
...
ADD_REGISTRY='--add-registry 172.30.138.33:5000 <rest of line>'
...
INSECURE_REGISTRY='--insecure-registry 172.30.138.33:5000 <rest of line>'
...



On each node:
# vi /usr/lib/systemd/system/docker.service
...
ExecStart=/usr/bin/dockerd-current \
--add-runtime docker-runc=/usr/libexec/docker/docker-runc-current \
--default-runtime=docker-runc \
--authorization-plugin=rhel-push-plugin \
--exec-opt native.cgroupdriver=systemd \
--userland-proxy-path=/usr/libexec/docker/docker-proxy-current \
--insecure-registry=172.30.138.33:5000 \
$OPTIONS \
...


Now restart docker on each node:

# systemctl daemon-reload
# systemctl restart docker



Make root an admin
This permits root to push images to the docker-registry.

# oadm policy add-cluster-role-to-user cluster-admin root



OCP Development Environment
Now that we have the cluster up running a recent puddle we can make changes to origin and test the results.The following is one of several ways to go about developing on Openshift. This was written during the OCP 3.6 development cycle. Things will change as time goes on.



There are three areas of development. Each is handled differently.

Develop commands
Develop openshift daemon changes
Develop container image changes


The general development cycle uses github tools and Openshift project procedures.

The development is done on a forked clone of  openshift/origin,  this example, is on a clone of origin on branch master.
https: //github.com/openshift/origin.git

In practice you will have your own forked clone and work on branches that you define.



Details of the development processes follow.



Develop commands
This is the simplest process. Just make changes to sources in origin, make and test the new image.

This can be done as long as the daemon APIs don't change because of the build.



Develop Openshift Daemon Changes
In this case the changes are made to the origin sources and built as above. The resulting Openshift executable must replace openshift on each node and the daemons must be restarted.



This example sets up openshift and its needed links in a new directory /opt/openshift/bin and uses NFS to share the directory. Systemd startup on each node is modified to run the new images.



Develop Container Image Changes
In this case the changes are made in the origin sources and built. The new/modified containers are generated, tagged and pushed to the docker-registry. The openshift deployment configuration is modified to use the image from the repository.

The pods are deleted and automatically restarted with the new image.



This is the most complex development process. The product builds an Openshift RPM and the image build uses that. The image build also builds all images. Both of these processes take substantial time. This example update the existing image with a new layer containing openshift and files from the origin/images directory for the image that is being built.



OCP Development
First set up a development environment on the cluster. Development can be done anywhere. Out of convenience it is done as the root user on netdev22 (the master node).



Configure Git
Git is the source control tool and it is convenient to set it up similar to the following:



# cat ~/.gitconfig
[gui]
recentrepo = /root/cluster-perf
[user]
name = XXXX XXXXXXX
email = xxxxxxxx@redhat.com
[sendemail]
smtpserver = smtp.corp.redhat.com
suppresscc = all
chainreplyto = false
[core]
editor = vim
[alias]
st = status
co = checkout
br = branch
up = rebase
ci = commit
[credential]
helper = cache
[push]
default = simple



Install GO
The version of go must match the version of the product you are building. For OCP 3.6, 3.5, 3.4, 3.3 use go version 1.7.4. For version 3.7 when Kubernetes 1.7 is merged, use 1.8.1. Using the wrong compiler causes difficult to understand problems.



On the chosen development node (master node):
# wget https://storage.googleapis.com/golang/go1.7.4.linux-amd64.tar.gz



Instructions to install go:
https://golang.org/doc/install



# cd /usr/local
# tar xfz go1.7.4.linux-amd64.tar.gz



Add /usr/local/go/bin to the PATH environment variable. You can do this by adding this line to your /etc/profile (for a system-wide installation) or $HOME/.profile or $HOME/.bashrc:
export PATH=/usr/local/go/bin:$PATH



Source the changes:

. ~/.bashrc



Verify the running version:

# go version
go version go1.7.4 linux/amd64





Clone Origin Repository
# git clone http://github.com/openshift/origin
# cd origin
# make


Local Configuration Changes
There are a number of things that need to be changed for the cluster to run the built image. The content of the built Openshift, both images and soft links need to be set up in an nfs served area and the nodes must start the daemons from that area.



Local access on the Build Host
The development cycle makes Openshift and copies it to the nfs share. Testing is done using this image, so set up access in $PATH

~/.bashrc
export PATH=/opt/openshift/bin:$PATH



. ~/.bashrc



Change ExecStart to Point to the NFS Share
On the master node:
# cp /usr/lib/systemd/system/atomic-openshift-master.service /usr/lib/systemd/system/atomic-openshift-master.service.save

# vi /usr/lib/systemd/system/atomic-openshift-master.service

ExecStart=/opt/openshift/bin/openshift start node --config=${CONFIG_FILE} $OPTIONS



On all nodes:
# cp /usr/lib/systemd/system/atomic-openshift-node.service /usr/lib/systemd/system/atomic-openshift-node.service.save
# vi /usr/lib/systemd/system/atomic-openshift-node.service
ExecStart=/opt/openshift/bin/openshift start node --config=${CONFIG_FILE} $OPTIONS



Set up Soft Links in NFS Share
cd /opt/openshift/bin
ln -s openshift kube-apiserver
ln -s openshift kube-controller-manager
ln -s openshift kubectl
ln -s openshift kubelet
ln -s openshift kube-proxy
ln -s openshift kubernetes
ln -s openshift kube-scheduler
ln -s openshift oadm
ln -s openshift openshift-deploy
ln -s openshift openshift-docker-build
ln -s openshift openshift-recycle
ln -s openshift openshift-router
ln -s openshift openshift-sti-build
ln -s openshift origin
ln -s openshift osadm
ln -s openshift osc



General Development Cycle
The general development cycle is along these lines:

Make code changes
Build ( make clean && make)
Stop cluster
Copy openshift to NFS share
Start cluster
Make container images
Docker tag and push to Openshift cluster registry
Delete running pod and wait for it to be restarted
Not all of these steps are needed depending on what you are working on.



Build
# cd origin

# make clean && make

The make clean is not always need. It is needed when you rebase.



Stop the cluster:
systemctl stop atomic-openshift-master.service
systemctl stop atomic-openshift-node.service
ssh root@netdev28 systemctl stop atomic-openshift-node.service
ssh root@netdev35 systemctl stop atomic-openshift-node.service

Next copy the built files to the /opt/openshift/bin NFS store:
cp _output/local/bin/linux/amd64/openshift /opt/openshift/bin/openshift
cp _output/local/bin/linux/amd64/oc /opt/openshift/bin/oc
cp _output/local/bin/linux/amd64/loopback /opt/openshift/bin/loopback
cp _output/local/bin/linux/amd64/sdn-cni-plugin /opt/openshift/bin/sdn-cni-plugin
cp _output/local/bin/linux/amd64/host-local /opt/openshift/bin/host-local
cp pkg/sdn/plugin/sdn-cni-plugin/80-openshift-sdn.conf /opt/openshift/bin/80-openshift-sdn.conf
cp pkg/sdn/plugin/bin/openshift-sdn-ovs /opt/openshift/bin/openshift-sdn-ovs

Usually the only interesting file tso copy are oc and openshift, since that is where the changes are usually made.



Reload the Daemons and Restart the Cluster
On each node:
systemctl daemon-reload

ssh root@netdev28 systemctl daemon-reload

ssh root@netdev35 systemctl daemon-reload


Start the cluster:
systemctl start atomic-openshift-master.service
systemctl start atomic-openshift-node.service
ssh root@netdev28 systemctl start atomic-openshift-node.service
ssh root@netdev35 systemctl start atomic-openshift-node.service



You are now running your changes to the openshift daemons. Developing in the containers such as the haproxy-router require additional steps. You need to build a new docker image and run it.



Develop Containers
Build the Container Image
The simplest approach is to use:

cd origin

./hack/build-local-images.py haproxy-router



This rebuilds the listed container, in this case haproxy-router.

It grabs the container from some source, maybe docker.io and adds a new layer that overlays openshift and all of the configuration files in the container.

The results:

# docker images | head
REPOSITORY TAG IMAGE ID CREATED SIZE
openshift/origin-haproxy-router latest 172952b56785 21 hours ago 1.912 GB

...

Tag and Push the Image to the Openshift Registry


Login to Openshift Registry using a docker login and Openshift token



You must be logged in as a regular user to get a token
# oc login -u root
token=$(oc whoami -t)
# oc login -u system:admin



Docker login to each node (netdev22 does the push, the others pull) all must be logged in.
# docker login -u admin -p $token 172.30.138.33:5000



Tag the image and push it.

The tag name is the Registry's Service IP adderss and port and the desired image name. This must match the image name in the pod.
docker tag openshift/origin-haproxy-router 172.30.138.33:5000/openshift/origin-haproxy-router-dev
docker push 172.30.138.33:5000/openshift/origin-haproxy-router-dev



Fix the router Deployment Configuration for the Image

You can either create a router using the --images= option or edit the existing router deployment configuration.



# oc edit dc/router
...
image: 172.30.138.33:5000/openshift/origin-haproxy-router-dev
imagePullPolicy: Always
...

The save forces a redeployment and a new pod.



You can now test and debug the container.



Post script
The above is a snapshot in time and since software continually evolves it may become obsolete. The key steps will likely always be needed in some form and hopefully this will be a useful guide for a while.
