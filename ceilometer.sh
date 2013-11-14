#!/usr/bin/env bash

function ceilometer_setup() {
  # install packages
  install_package ceilometer-agent-central ceilometer-api ceilometer-collector ceilometer-common python-ceilometer python-ceilometerclient

  # create database for ceilometer
  mysql -uroot -p${mysql_pass} -e "create database ceilometer;"
  mysql -uroot -p${mysql_pass} -e "grant all on ceilometer.* to '${db_ceilometer_user}'@'%' identified by '${db_ceilometer_pass}';"

  # set configuration files
  setconf infile:$base_dir/conf/etc.ceilometer/ceilometer.conf \
    outfile:/etc/ceilometer/ceilometer.conf \
    "<db_ceilometer_user>:${db_ceilometer_user}" \
    "<db_ceilometer_pass>:${db_ceilometer_pass}" \
    "<ceilometer_ip>:${ceilometer_ip}" \
    "<keystone_ip>:${keystone_ip}" \
    "<rabbit_ip>:${rabbit_ip}" \
    "<service_password>:${service_password}"

  # restart all of cinder services
  restart_service ceilometer-agent-central
  restart_service ceilometer-api
  restart_service ceilometer-collector 

  ceilometer-dbsync
}

function ceilometer_agent_setup() {
  # install packages
  install_package ceilometer-common python-ceilometer python-ceilometerclient ceilometer-agent-compute

  # set configuration files
  if [[ "$1" = "compute" ]]; then
    setconf infile:$base_dir/conf/etc.ceilometer/ceilometer.conf \
      outfile:/etc/ceilometer/ceilometer.conf \
      "<db_ceilometer_user>:${db_ceilometer_user}" \
      "<db_ceilometer_pass>:${db_ceilometer_pass}" \
      "<ceilometer_ip>:${ceilometer_ip}" \
      "<keystone_ip>:${keystone_ip}" \
      "<rabbit_ip>:${rabbit_ip}" \
      "<service_password>:${service_password}"
  fi

  # restart all of cinder services
  restart_service ceilometer-agent-compute
}

