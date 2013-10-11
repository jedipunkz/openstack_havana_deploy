#!/usr/bin/env bash

function horizon_setup() {
  # install horizon packages
  install_package openstack-dashboard memcached

  # set configuration file
  # cp $base_dir/conf/etc.openstack-dashboard/local_settings.py /etc/openstack-dashboard/local_settings.py

  # restart horizon services
  service apache2 restart
  service memcached restart
}
