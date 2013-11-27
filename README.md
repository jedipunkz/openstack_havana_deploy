OpenStack Havana Installation Script
====

OpenStack Havana Installation Bash Script for Ubuntu Server 12.04 LTS.

Author
----

Tomokazu Hirai @jedipunkz

Twitter : <https://twitter.com/jedipunkz>
Blog    : <http://jedipunkz.github.io>

Notice
----

This script was tested ..

* all in one node with neutron (vlan mode)
* separated nodes (controller node, network node, compute x n) with neutron (vlan mode)

in these cases, it is not already done.

* all in one node with nova-network
* separated nodes (controller node, compute x n) with nova-network

Motivation
----

devstack is very usefull for me. I am using devstack for understanding
openstack, especially Neutron ! ;) but when I reboot devstack node, all of
openstack compornents was not booted. That is not good for me. and I wanted to
use Ubuntu Cloud Archive packages.

Require Environment
----

#### Cinder Device

If you want use REAL disk device for cinder such as /dev/sdb, please input disk
device name to $CINDER_VOLUME in setup.conf. If you do not have any additional
disk for cinder, you can use loopback device. So please input loopback device
name such as /dev/loop3.

#### In All in ne node mode

You need 2 NICs (management network, public network). You can run this script
via management network NIC. VM can access to the internet via public network
NIC (default : eth0, You can change device on setup.conf).

#### In separated nodes mode

You need 3 NICs for ..

* management network
* public network / API network (default: eth0)
* data network (default: eth1)

for more details, please see this doc. 

<http://docs.openstack.org/trunk/openstack-network/admin/content/app_demo_single_router.html>

Neutron was designed on 4 networks (public, data, managememt, api) so You can
3 NICs on separated nodes mode. API network and Public network can share same
network segment or you can separate these networks. This README's
configuration of the premise is sharing a segment with API and Public network
(default NIC : eth0).

How to use on All in One Node with neutron
----

#### Architecture

    +------------------- Public/API Network
    |
    +------------+
    |vm|vm|...   |
    +------------+
    | all in one |
    +------------+
    |     |      
    +-----)------------- Management/API Network
          |             
          +------------- Data Network

* all of compornetns are on same node.

#### Setup network interfaces

Please setup network interfaces just like this.

    % sudo ${EDITOR} /etc/network/interfaces
    auto lo
    iface lo inet loopback
    
    # this NIC will be used for VM traffic to the internet
    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down
        address 10.200.9.10
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search example.com

    auto eth1
    iface eth1 inet static
        address 172.16.0.10
        netmask 255.255.255.0

    # this NIC must be on management network
    auto eth2
    iface eth2 inet static
        address 10.200.10.10
        netmask 255.255.255.0
        gateway 10.200.10.1
        dns-nameservers 8.8.8.8 8.8.4.4

login and use this script via eth1 on management network. eth0 will be lost
connectivity when you run this script. and make sure hostname resolv at
/etc/hosts. in this sample, your host need resolv self fqdn in 10.200.10.10

#### Get this script

git clone this script from github.

    % git clone git://github.com/jedipunkz/openstack_havana_deploy.git
    % cd openstack_havana_deploy
    % cp setup.conf.samples/setup.conf.allinone.neutron setup.conf
    
#### Edit parameters on setup.conf

There are many paramaters on setup.conf, but in 'allinone' mode, parameters
which you need to edit is such things.

    HOST_IP='10.200.10.10'
    HOST_PUB_IP='10.200.9.10'
    PUBLICNETWORK_NIC_NETWORK_NODE='eth0'
    NETWORK_COMPONENT='neutron'

If you want to change other parameters such as DB password, admin password,
please change these.

#### Run script

Run this script, all of conpornents will be built.

    % sudo ./setup.sh allinone
    % sudo ./setup.sh create_network

That's all and You've done. :D Now you can access to Horizon
(http://${HOST_IP}/horizon/) with user 'demo', password 'demo'.

How to use on separated nodes mode with quatum
----

#### Architecture

    +-------------+-------------+------------------------------ Public/API Network
    |             |             |             
    +-----------+ +-----------+ +-----------+ +-----------+ +-----------+
    |           | |           | |           | |vm|vm|..   | |vm|vm|..   |
    | controller| |  network  | |  network  | +-----------+ +-----------+
    |           | |           | | additional| |  compute  | |  compute  |
    |           | |           | |           | |           | | additional|
    +-----------+ +-----------+ +-----------+ +-----------+ +-----------+
    |             |     |       |     |       |     |       |
    +-------------+-----)-------+-----)-------+-----)-------)-- Management/API Network
                        |             |             |       |
                        +-------------+-------------+---------- Data Network

* minimum architecture : 3 nodes (controller node x 1, network node x 1, compute node x1)
* You can add some network nodes and compute nodes.
* additional network node(s) make you be able to have duplication of each agent
* additional compute node(s) make you be able to have more VMs.

#### Get this script

git clone this script from github on controller node.

    controller% git clone git://github.com/jedipunkz/openstack_havana_deploy.git
    controller% cd openstack_havana_deploy
    controller% cp setup.conf.samples/setup.conf.separated.neutron setup.conf
    
#### Edit parameters on setup.conf

There are many paramaters on setup.conf, but in 'allinone' mode, parameters
which you need to edit is such things.

    CONTROLLER_NODE_IP='10.200.10.10'
    CONTROLLER_NODE_PUB_IP='10.200.9.10'
    NETWORK_NODE_IP='10.200.10.11'
    COMPUTE_NODE_IP='10.200.10.12'
    DATANETWORK_NIC_NETWORK_NODE='eth1'
    DATANETWORK_NIC_COMPUTE_NODE='eth0'
    PUBLICNETWORK_NIC_NETWORK_NODE='eth0'
    NETWORK_COMPONENT='neutron'
    
If you want to change other parameters such as DB password, admin password,
please change these.

#### copy to other nodes

copy directory to network node and compute node.

    controller% scp -r openstack_havana_deploy <network_node_ip>:~/
    controller% scp -r openstack_havana_deploy <compute_node_ip>:~/

#### Controller Node's network interfaces

Set up NICs for controller node.

    controller% sudo ${EDITOR} /etc/network/interfaces
    # The loopback network interface
    auto lo
    iface lo inet loopback
    
    # for API network
    auto eth0
    iface eth0 inet static
        address 10.200.9.10
        netmask 255.255.255.0
        gateway 10.200.9.1
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search example.com

    # for management network
    auto eth1
    iface eth1 inet static
        address 10.200.10.10
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search example.com

and login to controller node via eth0 (public network) for executing this script.
Other NIC will lost connectivity. and make sure hostname resolv at
/etc/hosts. in this sample, your host need resolv self fqdn in 10.200.9.10

#### Network Node's network interfaces

Set up NICs for network node.

    network% sudo ${EDITOR} /etc/network/interfaces
    # The loopback network interface
    auto lo
    iface lo inet loopback
    
    # for API network
    auto eth0
    iface eth0 inet static
        up ifconfig $IFACE 0.0.0.0 up
        up ip link set $IFACE promisc on
        down ip link set $IFACE promisc off
        down ifconfig $IFACE down
        address 10.200.9.11
        netmask 255.255.255.0
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search example.com

    # for VM traffic to the internet
    auto eth1
    iface eth1 inet static
        address 172.16.1.11
        netmask 255.255.255.0

    # for management network
    auto eth2
    iface eth2 inet static
        address 10.200.10.11
        netmask 255.255.255.0
        gateway 10.200.10.1
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search example.com

and login to network node via eth2 (management network) for executing this
script. Other NIC will lost connectivity.

#### Compute Node's network interfaces

Set up NICs for network node.

    compute% sudo ${EDITOR} /etc/network/interfaces
    # The loopback network interface
    auto lo
    iface lo inet loopback
    
    # for VM traffic to the internet
    auto eth0
    iface eth0 inet static
        address 172.16.1.12
        netmask 255.255.255.0

    # for management network
    auto eth1
    iface eth1 inet static
        address 10.200.10.12
        netmask 255.255.255.0
        gateway 10.200.10.1
        dns-nameservers 8.8.8.8 8.8.4.4
        dns-search example.com

and login to compute node via eth2 (mangement network) for executing this
script. Other NIC will lost connectivity.

#### Run script

Run this script, all of conpornents will be built.

    controller% sudo ./setup.sh controller
    network   % sudo ./setup.sh network
    compute   % sudo ./setup.sh comupte
    controller% sudo ./setup.sh create_network # <- creating virtual network

That's all and You've done. :D Now you can access to Horizon
(http://${CONTROLLER_NODE_PUB_IP}/horizon/) with user 'demo', password 'demo'.

#### Additional Compute Node

If you want to have additional compute node(s), please setup network
interfaces as noted before for compute node and execute these commands.

Edit setup.conf (COPUTE_NODE_IP parameter) and execute setup.sh.

    compute    % scp -r ~/openstack_havana_deploy <add_compute_node>:~/
    add_compute% cd openstack_havana_deploy
    add_compute% ${EDITOR} setup.conf
    COMPUTE_NODE_IP='<your additional compute node's ip>'
    add_compute% sudo ./setup.sh compute
    add_compute% sudo nova-manage service list # check nodes list

#### Additional Network Node

If you want to have additional network node(s), please setup network
interfaces as noted before for network node and execute these commands.

Edit setup.conf (NETWORK_NODE_IP parameter) and execute setup.sh.

    network    % scp -r ~/openstack_havana_deploy <add_network_node>:~/
    add_network% cd openstack_havana_deploy
    add_network% ${EDITOR} setup.conf
    NETWORK_NODE_IP='<your additional network node's ip>'
    add_network% sudo ./setup.sh network
    add_network% source ~/openstackrc
    add_network% neutron agent-list # check agent list
    

Parameters
----

These are Meaning of parameters.

* host_ip : ip addr on management network with 'allinone' node
* host_pub_ip : ip addr on public network with 'allinone' node
* public_nic : nic name on public network with 'allinone' node
* controller_node_ip : ip addr on management network with controller node
* controller_node_pub_ip : ip addr on public network with controller node
* network_node_ip : ip addr on management network with network node
* compute_node_ip : ip addr on management network with compute node
* data_nic_controller : nic name on data network with controller node
* data_nic_compute : nic name on data network with compute nod
* public_nic : nic name on public network on network node
* cinder_volume : disk device name for cinder volume
* mysql_pass : root password of mysql
* db_keystone_user : mysql user for keystone
* db_keystone_pass : mysql password for keystone
* db_glance_user : mysql user for glance
* db_glancepass : mysql password for glance
* db_neutron_user : mysql user for neutron
* db_neutron_pass : mysql password for neutron
* db_nova_user : mysql user for nova
* db_nova_pass : mysql password for nova
* db_cinder_user : mysql user for cinder
* db_cinder_pass : mysql password for cinder
* admin_password : keystone password for admin user
* service_password : keystone password for service user
* os_tenant_name : os tenant name
* os_username : os username
* os_password : os password
* demo_user : first user for demo
* demo_password : first user's password for demo
* int_net_gateway : gateway address of internal network
* int_net_range : range of external network
* ext_net_gateway : gateway address of external network
* ext_net_start : starging address of external network
* ext_net_end : ending address of external network
* ext_net_range : range of external network
* os_image_url : url for downloading os image file
* os_image_name : name of os image name for glance service

Licensing
----

This Script  is licensed under a Creative Commons Attribution 3.0 Unported License.

To view a copy of this license, visit
[ http://creativecommons.org/licenses/by/3.0/deed.en_US ].

Known Issue
----

* can not access vm via neutron gre tunnel (see bug https://bugs.launchpad.net/neutron/+bug/1238445)

Version and Change log
----

* version 0.1 : 25th Oct 2013 : first version of release. tested for neutron mode only.
