#!/usr/bin/env bash

# --------------------------------------------------------------------------------------
# initialization function
# --------------------------------------------------------------------------------------
function init() {
  # at first, update package repository cache
  apt-get update

  # install ntp
  install_package ntp
  cp $base_dir/conf/etc.ntp.conf /etc/ntp.conf

  # install misc software
  apt-get install -y vlan bridge-utils

  # use ubuntu cloud archive repository
  # this script needs ubuntu cloud archive for grizzly, so we are using 12.04 lts.
  apt-get install ubuntu-cloud-keyring
  #echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-updates/havana main >> /etc/apt/sources.list.d/grizzly.list
  echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu precise-proposed/havana main > /etc/apt/sources.list.d/havana.list
  apt-get update
}

# --------------------------------------------------------------------------------------
# set shell environment
# --------------------------------------------------------------------------------------
function shell_env() {

  # set environments for 'admin' user, this script will be operated with this user
  export OS_TENANT_NAME=${os_tenant_name}
  export OS_USERNAME=${os_username}
  export OS_PASSWORD=${os_password}
  export SERVICE_TOKEN=${service_token}
  export OS_AUTH_URL="http://${keystone_ip}:5000/v2.0/"
  export SERVICE_ENDPOINT="http://${keystone_ip}:35357/v2.0"

  # create ~/openstackrc for 'admin' user
  echo "export OS_TENANT_NAME=${os_tenant_name}" > ~/openstackrc
  echo "export OS_USERNAME=${os_username}" >> ~/openstackrc
  echo "export OS_PASSWORD=${os_password}" >> ~/openstackrc
  echo "export SERVICE_TOKEN=${service_token}" >> ~/openstackrc
  echo "export OS_AUTH_URL=\"http://${keystone_ip}:5000/v2.0/\"" >> ~/openstackrc
  if [[ "$1" = "allinone" ]]; then
    echo "export SERVICE_ENDPOINT=\"http://${keystone_ip}:35357/v2.0\"" >> ~/openstackrc
  elif [[ "$1" = "separate" ]]; then
    echo "export SERVICE_ENDPOINT=\"http://${controller_node_pub_ip}:35357/v2.0\"" >> ~/openstackrc
  else
    echo "mode must be allinone or separate."
    exit 1
  fi

  # create openstackrc for 'demo' user. this user is useful for horizon or to access each apis by demo.
  echo "export OS_TENANT_NAME=service" > ~/openstackrc-demo
  echo "export OS_USERNAME=${demo_user}" >> ~/openstackrc-demo
  echo "export OS_PASSWORD=${demo_password}" >> ~/openstackrc-demo
  echo "export SERVICE_TOKEN=${service_token}" >> ~/openstackrc-demo
  echo "export OS_AUTH_URL=\"http://${keystone_ip}:5000/v2.0/\"" >> ~/openstackrc-demo
  if [[ "$1" = "allinone" ]]; then
    echo "export SERVICE_ENDPOINT=http://${keystone_ip}:35357/v2.0" >> ~/openstackrc-demo
  elif [[ "$1" = "separate" ]]; then
    echo "export SERVICE_ENDPOINT=http://${controller_node_pub_ip}:35357/v2.0" >> ~/openstackrc-demo
  else
    echo "mode must be allinone or separate."
    exit 1
  fi
}

# --------------------------------------------------------------------------------------
# install mysql
# --------------------------------------------------------------------------------------
function mysql_setup() {
  # set mysql root user's password
  echo mysql-server-5.5 mysql-server/root_password password ${mysql_pass} | debconf-set-selections
  echo mysql-server-5.5 mysql-server/root_password_again password ${mysql_pass} | debconf-set-selections
  # install mysql and rabbitmq
  install_package mysql-server python-mysqldb

  # enable to access from the other nodes to local mysqld via network
  sed -i -e  "s/^\(bind-address\s*=\).*/\1 0.0.0.0/" /etc/mysql/my.cnf
  restart_service mysql

  # misc software
  install_package rabbitmq-server
}

# --------------------------------------------------------------------------------------
# install keystone
# --------------------------------------------------------------------------------------
function keystone_setup() {
  # install keystone daemon and client software
  install_package keystone python-keystone python-keystoneclient

  # create database for keystone
  mysql -uroot -p${mysql_pass} -e "create database keystone;"
  mysql -uroot -p${mysql_pass} -e "grant all on keystone.* to '${db_keystone_user}'@'%' identified by '${db_keystone_pass}';"

  # set configuration file
  setconf infile:$base_dir/conf/etc.keystone/keystone.conf \
    outfile:/etc/keystone/keystone.conf \
    "<keystone_ip>:${keystone_ip}" \
    "<db_keystone_user>:${db_keystone_user}" \
    "<db_keystone_pass>:${db_keystone_pass}"

  # restart keystone
  restart_service keystone
  # input keystone database to mysqld
  keystone-manage db_sync
  
  # create tenants
  tenant_id_admin=$(keystone tenant-create --name admin | grep ' id ' | get_field 2)
  tenant_id_service=$(keystone tenant-create --name service | grep ' id ' | get_field 2)
  
  # create users
  user_id_admin=$(keystone user-create --name admin --pass ${admin_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
  user_id_nova=$(keystone user-create --name nova --pass ${service_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
  user_id_glance=$(keystone user-create --name glance --pass ${service_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
  user_id_cinder=$(keystone user-create --name cinder --pass ${service_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
  user_id_demo=$(keystone user-create --name ${demo_user} --pass ${demo_password} --tenant-id ${tenant_id_service} --email demo@example.com | grep ' id ' | get_field 2)
  if [[ "$1" = "neutron" ]]; then
    user_id_neutron=$(keystone user-create --name neutron --pass ${service_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
  fi
  
  # create roles
  role_id_admin=$(keystone role-create --name admin | grep ' id ' | get_field 2)
  role_id_keystone_admin=$(keystone role-create --name=keystoneadmin | grep ' id ' | get_field 2)
  role_id_keystone_service=$(keystone role-create --name=keystoneservice | grep ' id ' | get_field 2)
  role_id_member=$(keystone role-create --name Member | grep ' id ' | get_field 2)
  
  # to add a role of 'admin' to the user 'admin' of the tenant 'admin'.
  keystone user-role-add --user-id ${user_id_admin} --role-id ${role_id_admin} --tenant-id ${tenant_id_admin}
  keystone user-role-add --user-id ${user_id_admin} --role-id ${role_id_keystone_admin} --tenant-id ${tenant_id_admin}
  keystone user-role-add --user-id ${user_id_admin} --role-id ${role_id_keystone_service} --tenant-id ${tenant_id_admin}
  
  # the following commands will add a role of 'admin' to the users 'nova', 'glance' and 'swift' of the tenant 'service'.
  keystone user-role-add --user-id ${user_id_nova} --role-id ${role_id_admin} --tenant-id ${tenant_id_service}
  keystone user-role-add --user-id ${user_id_glance} --role-id ${role_id_admin} --tenant-id ${tenant_id_service}
  keystone user-role-add --user-id ${user_id_cinder} --role-id ${role_id_admin} --tenant-id ${tenant_id_service}
  if [[ "$1" = "neutron" ]]; then
    keystone user-role-add --user-id ${user_id_neutron} --role-id ${role_id_admin} --tenant-id ${tenant_id_service}
  fi
  
  # the 'member' role is used by horizon and swift. so add the 'member' role accordingly.
  keystone user-role-add --user-id ${user_id_admin} --role-id ${role_id_member} --tenant-id ${tenant_id_admin}
  keystone user-role-add --user-id ${user_id_demo} --role-id ${role_id_member} --tenant-id ${tenant_id_service}
  
  # creating services
  service_id_compute=$(keystone service-create --name nova --type compute --description 'openstack compute service' | grep ' id ' | get_field 2)
  service_id_image=$(keystone service-create --name glance --type image --description 'openstack image service' | grep ' id ' | get_field 2)
  service_id_volume=$(keystone service-create --name cinder --type volume --description 'openstack volume service' | grep ' id ' | get_field 2)
  service_id_identity=$(keystone service-create --name keystone --type identity --description 'openstack identity service' | grep ' id ' | get_field 2)
  service_id_ec2=$(keystone service-create --name ec2 --type ec2 --description 'ec2 service' | grep ' id ' | get_field 2)
  if [[ "$1" = "neutron" ]]; then
    service_id_neutron=$(keystone service-create --name neutron --type network --description 'openstack networking service' | grep ' id ' | get_field 2)
  fi

  # check service list that we just made
  keystone service-list
  
  # create endpoints
  if [[ "$2" = "controller" ]]; then
    keystone endpoint-create --region myregion --service_id $service_id_ec2 --publicurl "http://${controller_node_pub_ip}:8773/services/cloud" --adminurl "http://${controller_node_ip}:8773/services/admin" --internalurl "http://${controller_node_ip}:8773/services/cloud"
    keystone endpoint-create --region myregion --service_id $service_id_identity --publicurl "http://${controller_node_pub_ip}:5000/v2.0" --adminurl "http://${controller_node_ip}:35357/v2.0" --internalurl "http://${controller_node_ip}:5000/v2.0"
    keystone endpoint-create --region myregion --service_id $service_id_volume --publicurl "http://${controller_node_pub_ip}:8776/v1/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $service_id_image --publicurl "http://${controller_node_pub_ip}:9292/v2" --adminurl "http://${controller_node_ip}:9292/v2" --internalurl "http://${controller_node_ip}:9292/v2"
    keystone endpoint-create --region myregion --service_id $service_id_compute --publicurl "http://${controller_node_pub_ip}:8774/v2/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s"
    if [[ "$1" = "neutron" ]]; then
      keystone endpoint-create --region myregion --service-id $service_id_neutron --publicurl "http://${controller_node_pub_ip}:9696/" --adminurl "http://${controller_node_ip}:9696/" --internalurl "http://${controller_node_ip}:9696/"
    fi
  else
    keystone endpoint-create --region myregion --service_id $service_id_ec2 --publicurl "http://${controller_node_ip}:8773/services/cloud" --adminurl "http://${controller_node_ip}:8773/services/admin" --internalurl "http://${controller_node_ip}:8773/services/cloud"
    keystone endpoint-create --region myregion --service_id $service_id_identity --publicurl "http://${controller_node_ip}:5000/v2.0" --adminurl "http://${controller_node_ip}:35357/v2.0" --internalurl "http://${controller_node_ip}:5000/v2.0"
    keystone endpoint-create --region myregion --service_id $service_id_volume --publicurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $service_id_image --publicurl "http://${controller_node_ip}:9292/v2" --adminurl "http://${controller_node_ip}:9292/v2" --internalurl "http://${controller_node_ip}:9292/v2"
    keystone endpoint-create --region myregion --service_id $service_id_compute --publicurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s"
    if [[ "$1" = "neutron" ]]; then
      keystone endpoint-create --region myregion --service-id $service_id_neutron --publicurl "http://${controller_node_ip}:9696/" --adminurl "http://${controller_node_ip}:9696/" --internalurl "http://${controller_node_ip}:9696/"
    fi
  fi

  # check endpoint list that we just made
  keystone endpoint-list
}

# --------------------------------------------------------------------------------------
# install glance
# --------------------------------------------------------------------------------------
function glance_setup() {
  # install packages
  install_package glance
  
  # create database for keystone service
  mysql -uroot -p${mysql_pass} -e "create database glance;"
  mysql -uroot -p${mysql_pass} -e "grant all on glance.* to '${db_glance_user}'@'%' identified by '${db_glance_pass}';"

  # set configuration files
  setconf infile:$base_dir/conf/etc.glance/glance-api.conf \
    outfile:/etc/glance/glance-api.conf \
    "<keystone_ip>:${keystone_ip}" "<db_ip>:${db_ip}" \
    "<db_glance_user>:${db_glance_user}" \
    "<db_glance_pass>:${db_glance_pass}"
  setconf infile:$base_dir/conf/etc.glance/glance-registry.conf \
    outfile:/etc/glance/glance-registry.conf \
    "<keystone_ip>:${keystone_ip}" "<db_ip>:${db_ip}" \
    "<db_glance_user>:${db_glance_user}" \
    "<db_glance_pass>:${db_glance_pass}"
  setconf infile:$base_dir/conf/etc.glance/glance-registry-paste.ini \
    outfile:/etc/glance/glance-registry-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.glance/glance-api-paste.ini \
    outfile:/etc/glance/glance-api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"

  
  # restart process and syncing database
  restart_service glance-registry
  restart_service glance-api
  
  # input glance database to mysqld
  glance-manage db_sync
}

# --------------------------------------------------------------------------------------
# add os image
# --------------------------------------------------------------------------------------
function os_add () {
  # backup exist os image
  if [[ -f ./os.img ]]; then
    mv ./os.img ./os.img.bk
  fi
  
  # download cirros os image
  wget --no-check-certificate ${os_image_url} -o ./os.img
  
  # add os image to glance
  glance image-create --name="${os_image_name}" --is-public true --container-format bare --disk-format qcow2 < ./os.img
}

# --------------------------------------------------------------------------------------
# install nova for all in one with neutron
# --------------------------------------------------------------------------------------
function allinone_nova_setup() {
  # install kvm and the others packages
  install_package kvm libvirt-bin pm-utils
  restart_service dbus
  sleep 3
  #virsh net-destroy default
  virsh net-undefine default
  restart_service libvirt-bin

  # install nova packages
  install_package nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor nova-compute-kvm
  # create database for nova
  mysql -u root -p${mysql_pass} -e "create database nova;"
  mysql -u root -p${mysql_pass} -e "grant all on nova.* to '${db_nova_user}'@'%' identified by '${db_nova_pass}';"

  # set configuration files
  setconf infile:$base_dir/conf/etc.nova/api-paste.ini outfile:/etc/nova/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.nova/nova.conf outfile:/etc/nova/nova.conf \
    "<metadata_listen>:${controller_node_ip}" "<controller_ip>:${controller_node_ip}" \
    "<vnc_ip>:${controller_node_ip}" "<db_ip>:${db_ip}" "<db_nova_user>:${db_nova_user}" \
    "<db_nova_pass>:${db_nova_pass}" "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}" "<local_ip>:${controller_node_ip}" \
    "<cinder_ip>:${controller_node_ip}"

  cp $base_dir/conf/etc.nova/nova-compute.conf /etc/nova/nova-compute.conf

  # input nova database to mysqld
  nova-manage db sync
  
  # restart all of nova services
  cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
  
  # check nova service list
  nova-manage service list
}

# --------------------------------------------------------------------------------------
# install nova for all in one with neutron
# --------------------------------------------------------------------------------------
function allinone_nova_setup_nova_network() {
  # install kvm and the others packages
  install_package kvm libvirt-bin pm-utils
  restart_service dbus
  sleep 3
  #virsh net-destroy default
  virsh net-undefine default
  restart_service libvirt-bin

  # install nova packages
  #install_package nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor nova-compute-kvm
  install_package nova-api nova-cert nova-common novnc nova-compute-kvm nova-consoleauth nova-scheduler nova-novncproxy vlan bridge-utils nova-network nova-console websockify nova-conductor
  # create database for nova
  mysql -u root -p${mysql_pass} -e "create database nova;"
  mysql -u root -p${mysql_pass} -e "grant all on nova.* to '${db_nova_user}'@'%' identified by '${db_nova_pass}';"

  # set configuration files
  setconf infile:$base_dir/conf/etc.nova/api-paste.ini outfile:/etc/nova/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.nova/nova.conf.nova-network outfile:/etc/nova/nova.conf \
    "<metadata_listen>:${controller_node_ip}" "<controller_ip>:${controller_node_ip}" \
    "<vnc_ip>:${controller_node_pub_ip}" "<db_ip>:${db_ip}" "<db_nova_user>:${db_nova_user}" \
    "<db_nova_pass>:${db_nova_pass}" "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}" "<local_ip>:${controller_node_ip}" \
    "<cinder_ip>:${controller_node_ip}" "<fixed_range>:${fixed_range}" \
    "<fixed_start_addr>:${fixed_start_addr}" "<network_size>:${network_size}" \
    "<flat_interface>:${flat_interface}" "<compute_ip>:${controller_node_ip}"

  # cp $base_dir/conf/etc.nova/nova-compute.conf /etc/nova/nova-compute.conf

  # input nova database to mysqld
  nova-manage db sync

  # restart all of nova services
  cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done

  # check nova service list
  nova-manage service list
}

# --------------------------------------------------------------------------------------
# install nova for controller node with nova-network
# --------------------------------------------------------------------------------------
function controller_nova_setup() {
  # install packages
  install_package nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor

  # create database for nova
  mysql -u root -p${mysql_pass} -e "create database nova;"
  mysql -u root -p${mysql_pass} -e "grant all on nova.* to '${db_nova_user}'@'%' identified by '${db_nova_pass}';"
  
  # set configuration files for nova
  setconf infile:$base_dir/conf/etc.nova/api-paste.ini outfile:/etc/nova/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.nova/nova.conf outfile:/etc/nova/nova.conf \
    "<metadata_listen>:${controller_node_ip}" "<controller_ip>:${controller_node_ip}" \
    "<vnc_ip>:${controller_node_pub_ip}" "<db_ip>:${db_ip}" "<db_nova_user>:${db_nova_user}" \
    "<db_nova_pass>:${db_nova_pass}" "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}" "<local_ip>:${controller_node_ip}" \
    "<cinder_ip>:${controller_node_ip}"
    

  # input nova database to mysqld
  nova-manage db sync
  
  # restart all of nova services
  cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
  
  # check nova service list
  nova-manage service list
}

# --------------------------------------------------------------------------------------
# 
# --------------------------------------------------------------------------------------
function controller_nova_setup_nova_network() {
  # install packages
  install_package nova-api nova-cert novnc nova-consoleauth nova-scheduler nova-novncproxy nova-doc nova-conductor

  # create database for nova
  mysql -u root -p${mysql_pass} -e "create database nova;"
  mysql -u root -p${mysql_pass} -e "grant all on nova.* to '${db_nova_user}'@'%' identified by '${db_nova_pass}';"
  
  # set configuration files for nova
  setconf infile:$base_dir/conf/etc.nova/api-paste.ini outfile:/etc/nova/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.nova/nova.conf.nova-network outfile:/etc/nova/nova.conf \
    "<metadata_listen>:${controller_node_ip}" "<controller_ip>:${controller_node_ip}" \
    "<vnc_ip>:${controller_node_pub_ip}" "<db_ip>:${db_ip}" "<db_nova_user>:${db_nova_user}" \
    "<db_nova_pass>:${db_nova_pass}" "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}" "<local_ip>:${controller_node_ip}" \
    "<cinder_ip>:${controller_node_ip}" "<fixed_range>:${fixed_range}" \
    "<fixed_start_addr>:${fixed_start_addr}" "<network_size>:${network_size}" \
    "<flat_interface>:${flat_interface}" "<compute_ip>:${compute_node_ip}"

  # input nova database to mysqld
  nova-manage db sync
  
  # restart all of nova services
  cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done
  
  # check nova service list
  nova-manage service list
}
# --------------------------------------------------------------------------------------
# create network with nova-network
# --------------------------------------------------------------------------------------
function create_network_nova_network() {
  nova-manage network create private --fixed_range_v4=${fixed_range} --num_networks=1 --bridge=br100 --bridge_interface=${flat_interface} --network_size=${network_size} --dns1=8.8.8.8 --dns2=8.8.4.4 --multi_host=t
  nova-manage floating create --ip_range=${floating_range}
}

# --------------------------------------------------------------------------------------
# install nova for compute node with neutron
# --------------------------------------------------------------------------------------
function compute_nova_setup() {
  # install dependency packages
  install_package vlan bridge-utils kvm libvirt-bin pm-utils sysfsutils
  restart_service dbus
  sleep 3
  #virsh net-destroy default
  virsh net-undefine default

  # enable live migration
  cp $base_dir/conf/etc.libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf
  sed -i 's/^env\ libvirtd_opts=\"-d\"/env\ libvirtd_opts=\"-d\ -l\"/g' /etc/init/libvirt-bin.conf
  sed -i 's/libvirtd_opts=\"-d\"/libvirtd_opts=\"-d\ -l\"/g' /etc/default/libvirt-bin
  restart_service libvirt-bin

  #
  # openvswitch
  #
  # install openvswitch and add bridge interfaces
  install_package openvswitch-switch

  # adding bridge and port
  ovs-vsctl add-br br-int
  ovs-vsctl add-br br-eth1
  ovs-vsctl add-port br-eth1 ${datanetwork_nic_compute_node}

  #
  # neutron
  #
  # install openvswitch neutron plugin
  install_package neutron-plugin-openvswitch-agent neutron-lbaas-agent

  # set configuration files
  if [[ "${network_type}" = 'gre' ]]; then
    setconf infile:$base_dir/conf/etc.neutron.plugins.openvswitch/ovs_neutron_plugin.ini.gre \
      outfile:/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini \
      "<db_ip>:${db_ip}" "<neutron_ip>:${compute_node_ip}" "<db_ovs_user>:${db_ovs_user}" \
      "<db_ovs_pass>:${db_ovs_pass}"
  elif [[ "${network_type}" = 'vlan' ]]; then
    setconf infile:$base_dir/conf/etc.neutron.plugins.openvswitch/ovs_neutron_plugin.ini.vlan \
      outfile:/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini \
      "<db_ip>:${db_ip}" "<neutron_ip>:${neutron_ip}" "<db_ovs_user>:${db_ovs_user}" \
      "<db_ovs_pass>:${db_ovs_pass}"
  else
    echo "network_type must be 'vlan' or 'gre'."
    exit 1
  fi
    
  setconf infile:$base_dir/conf/etc.neutron/neutron.conf \
    outfile:/etc/neutron/neutron.conf \
    "<controller_node_ip>:${controller_node_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}" \
    "<db_neutron_user>:${db_neutron_user}" \
    "<db_neutron_pass>:${db_neutron_pass}"

  # restart ovs agent
  service neutron-plugin-openvswitch-agent restart

  #
  # nova
  #
  # instll nova package
  install_package nova-compute-kvm

  # set configuration files
  setconf infile:$base_dir/conf/etc.nova/api-paste.ini \
    outfile:/etc/nova/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.nova/nova.conf \
    outfile:/etc/nova/nova.conf \
    "<metadata_listen>:127.0.0.1" "<controller_ip>:${controller_node_ip}" \
    "<vnc_ip>:${controller_node_pub_ip}" "<db_ip>:${db_ip}" \
    "<db_nova_user>:${db_nova_user}" "<db_nova_pass>:${db_nova_pass}" \
    "<service_tenant_name>:${service_tenant_name}" "<service_password>:${service_password}" \
    "<local_ip>:${compute_node_ip}" "<cinder_ip>:${controller_node_ip}"
  cp $base_dir/conf/etc.nova/nova-compute.conf /etc/nova/nova-compute.conf

  # restart all of nova services
  cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done

  # check nova services
  nova-manage service list
}

# --------------------------------------------------------------------------------------
# install nova for compute node with nova-network
# --------------------------------------------------------------------------------------
function compute_nova_setup_nova_network() {
  # install dependency packages
  install_package vlan bridge-utils kvm libvirt-bin pm-utils sysfsutils
  restart_service dbus
  sleep 3
  #virsh net-destroy default
  virsh net-undefine default

  # enable live migration
  cp $base_dir/conf/etc.libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf
  sed -i 's/^env\ libvirtd_opts=\"-d\"/env\ libvirtd_opts=\"-d\ -l\"/g' /etc/init/libvirt-bin.conf
  sed -i 's/libvirtd_opts=\"-d\"/libvirtd_opts=\"-d\ -l\"/g' /etc/default/libvirt-bin
  restart_service libvirt-bin

  # instll nova package
  install_package nova-compute-kvm nova-network nova-api-metadata

  # set configuration files
  setconf infile:$base_dir/conf/etc.nova/api-paste.ini \
    outfile:/etc/nova/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"
  setconf infile:$base_dir/conf/etc.nova/nova.conf.nova-network outfile:/etc/nova/nova.conf \
    "<metadata_listen>:${compute_node_ip}" "<controller_ip>:${controller_node_ip}" \
    "<vnc_ip>:${controller_node_pub_ip}" "<db_ip>:${db_ip}" "<db_nova_user>:${db_nova_user}" \
    "<db_nova_pass>:${db_nova_pass}" "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}" "<local_ip>:${compute_node_ip}" \
    "<cinder_ip>:${controller_node_ip}" "<fixed_range>:${fixed_range}" \
    "<fixed_start_addr>:${fixed_start_addr}" "<network_size>:${network_size}" \
    "<flat_interface>:${flat_interface}" "<compute_ip>:${compute_node_ip}"
  
  #cp $base_dir/conf/etc.nova/nova-compute.conf /etc/nova/nova-compute.conf

  # restart all of nova services
  cd /etc/init.d/; for i in $( ls nova-* ); do sudo service $i restart; done

  # check nova services
  nova-manage service list
}

# --------------------------------------------------------------------------------------
# install cinder
# --------------------------------------------------------------------------------------
function cinder_setup() {
  # install packages
  install_package cinder-api cinder-scheduler cinder-volume iscsitarget open-iscsi iscsitarget-dkms

  # setup iscsi
  setconf infile:/etc/default/iscsitarget "false:true"
  service iscsitarget start
  service open-iscsi start
  
  # create database for cinder
  mysql -uroot -p${mysql_pass} -e "create database cinder;"
  mysql -uroot -p${mysql_pass} -e "grant all on cinder.* to '${db_cinder_user}'@'%' identified by '${db_cinder_pass}';"
  
  # set configuration files
  if [[ "$1" = "controller" ]]; then
    setconf infile:$base_dir/conf/etc.cinder/api-paste.ini \
      outfile:/etc/cinder/api-paste.ini \
      "<keystone_ip>:${keystone_ip}" \
      "<controller_pub_ip>:${controller_node_pub_ip}" \
      "<service_tenant_name>:${service_tenant_name}" \
      "<service_password>:${service_password}"
  elif [[ "$1" = "allinone" ]]; then
    setconf infile:$base_dir/conf/etc.cinder/api-paste.ini \
      outfile:/etc/cinder/api-paste.ini \
      "<keystone_ip>:${keystone_ip}" \
      "<controller_pub_ip>:${controller_node_ip}" \
      "<service_tenant_name>:${service_tenant_name}" \
      "<service_password>:${service_password}"
  else
    echo "warning: mode must be 'allinone' or 'controller'."
    exit 1
  fi
  setconf infile:$base_dir/conf/etc.cinder/cinder.conf \
    outfile:/etc/cinder/cinder.conf \
    "<db_ip>:${db_ip}" "<db_cinder_user>:${db_cinder_user}" \
    "<db_cinder_pass>:${db_cinder_pass}" \
    "<cinder_ip>:${controller_node_ip}"

  # input database for cinder
  cinder-manage db sync

  if echo "$cinder_volume" | grep "loop" ; then
    dd if=/dev/zero of=/var/lib/cinder/volumes-disk bs=2 count=0 seek=7g
    file=/var/lib/cinder/volumes-disk
    modprobe loop
    losetup $cinder_volume $file
    pvcreate $cinder_volume
    vgcreate cinder-volumes $cinder_volume
  else
    # create pyshical volume and volume group
    pvcreate ${cinder_volume}
    vgcreate cinder-volumes ${cinder_volume}
  fi

  # disable tgt daemon
  stop_service tgt
  mv /etc/init/tgt.conf /etc/init/tgt.conf.disabled
  service iscsitarget restart

  # restart all of cinder services
  # restart_service cinder-volume
  # restart_service cinder-api
  # restart_service cinder-scheduler
  service cinder-volume restart
  service cinder-api restart
  service cinder-scheduler restart
}

# --------------------------------------------------------------------------------------
# install horizon
# --------------------------------------------------------------------------------------
function horizon_setup() {
  # install horizon packages
  install_package openstack-dashboard memcached

  # set configuration file
  # cp $base_dir/conf/etc.openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py
  
  # restart horizon services
  #restart_service apache2
  service apache2 restart
  #restart_service memcached
  service memcached restart
}

# --------------------------------------------------------------------------------------
#  make seciruty group rule named 'default' to allow ssh and icmp traffic
# --------------------------------------------------------------------------------------
# this function enable to access to the instances via ssh and icmp.
# if you want to add more rules named default, you can add it.
function scgroup_allow() {
  # switch to 'demo' user
  # we will use 'demo' user to access each api and instances, so it switch to 'demo'
  # user for security group setup.
  export SERVICE_TOKEN=${service_token}
  export OS_TENANT_NAME=service
  export OS_USERNAME=${demo_user}
  export OS_PASSWORD=${demo_password}
  export OS_AUTH_URL="http://${keystone_ip}:5000/v2.0/"
  export SERVICE_ENDPOINT="http://${keystone_ip}:35357/v2.0"

  # add ssh, icmp allow rules which named 'default'
  #nova --no-cache secgroup-add-rule default tcp 22 22 0.0.0.0/0
  #nova --no-cache secgroup-add-rule default icmp -1 -1 0.0.0.0/0
  neutron security-group-rule-create --protocol icmp --direction ingress default
  neutron security-group-rule-create --protocol tcp --port-range-min 22 --port-range-max 22 --direction ingress default

  # switch to 'admin' user
  # this script need 'admin' user, so turn back to admin.
  export SERVICE_TOKEN=${service_token}
  export OS_TENANT_NAME=${os_tenant_name}
  export OS_USERNAME=${os_username}
  export OS_PASSWORD=${os_password}
  export OS_AUTH_URL="http://${keystone_ip}:5000/v2.0/"
  export SERVICE_ENDPOINT="http://${keystone_ip}:35357/v2.0"
}

# --------------------------------------------------------------------------------------
# install openvswitch
# --------------------------------------------------------------------------------------
function openvswitch_setup() {
  install_package openvswitch-switch openvswitch-datapath-dkms
  # create bridge interfaces
  ovs-vsctl add-br br-int
  ovs-vsctl add-br br-eth1
  if [[ "$1" = "network" ]]; then
    ovs-vsctl add-port br-eth1 ${datanetwork_nic_network_node}
  fi
  ovs-vsctl add-br br-ex
  ovs-vsctl add-port br-ex ${publicnetwork_nic_network_node}
}
