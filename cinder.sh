#!/usr/bin/env bash

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
  service cinder-volume restart
  service cinder-api restart
  service cinder-scheduler restart
}

