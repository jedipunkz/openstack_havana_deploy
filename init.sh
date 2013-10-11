#!/usr/bin/env bash

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
