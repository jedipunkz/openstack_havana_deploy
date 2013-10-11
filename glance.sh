#!/usr/bin/env bash

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

