#!/usr/bin/env bash

function heat_setup() {
  # install packages
  install_package heat-api heat-api-cfn

  # create database for cinder
  mysql -uroot -p${mysql_pass} -e "create database heat;"
  mysql -uroot -p${mysql_pass} -e "grant all on heat.* to '${db_heat_user}'@'%' identified by '${db_heat_pass}';"

  # set configuration files
  setconf infile:$base_dir/conf/etc.heat/api-paste.ini \
    outfile:/etc/heat/api-paste.ini \
    "<keystone_ip>:${keystone_ip}" \
    "<service_tenant_name>:${service_tenant_name}" \
    "<service_password>:${service_password}"

  # input database for heat
  heat-manage db_sync

  # restart all of cinder services
  service heat-api restart
  service heat-api-cfn restart
}

