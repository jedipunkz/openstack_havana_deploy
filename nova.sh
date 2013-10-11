#!/usr/bin/env bash

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

function create_network_nova_network() {
  nova-manage network create private --fixed_range_v4=${fixed_range} --num_networks=1 --bridge=br100 --bridge_interface=${flat_interface} --network_size=${network_size} --dns1=8.8.8.8 --dns2=8.8.4.4 --multi_host=t
  nova-manage floating create --ip_range=${floating_range}
}

function compute_nova_setup() {
  install_package vlan bridge-utils kvm libvirt-bin pm-utils sysfsutils nova-compute-kvm
  restart_service dbus
  sleep 3
  virsh net-undefine default

  # enable live migration
  cp $base_dir/conf/etc.libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf
  sed -i 's/^env\ libvirtd_opts=\"-d\"/env\ libvirtd_opts=\"-d\ -l\"/g' /etc/init/libvirt-bin.conf
  sed -i 's/libvirtd_opts=\"-d\"/libvirtd_opts=\"-d\ -l\"/g' /etc/default/libvirt-bin
  restart_service libvirt-bin

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


