#!/usr/bin/env bash

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
  user_id_heat=$(keystone user-create --name heat --pass ${service_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
  user_id_ceilometer=$(keystone user-create --name ceilometer --pass ${service_password} --tenant-id ${tenant_id_service} --email admin@example.com | grep ' id ' | get_field 2)
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
  keystone user-role-add --user-id ${user_id_heat} --role-id ${role_id_admin} --tenant-id ${tenant_id_service}
  keystone user-role-add --user-id ${user_id_ceilometer} --role-id ${role_id_admin} --tenant-id ${tenant_id_service}
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
  service_id_heat=$(keystone service-create --name heat --type orchestration --description 'openstack orchestration service' | grep ' id ' | get_field 2)
  service_id_heat_cfn=$(keystone service-create --name heat-cfn --type cloudformation --description 'openstack cloudformation service' | grep ' id ' | get_field 2)
  service_id_ceilometer=$(keystone service-create --name ceilometer --type metering --description 'openstack metering service' | grep ' id ' | get_field 2)
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
    keystone endpoint-create --region myregion --service_id $service_id_heat --publicurl "http://${controller_node_pub_ip}:8004/v1/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8004/v1/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8004/v1/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $service_id_heat_cfn --publicurl "http://${controller_node_pub_ip}:8000/v1" --adminurl "http://${controller_node_ip}:8000/v1" --internalurl "http://${controller_node_ip}:8000/v1"
    keystone endpoint-create --region myregion --service_id $service_id_ceilometer --publicurl "http://${controller_node_pub_ip}:8777" --adminurl "http://${controller_node_ip}:8777" --internalurl "http://${controller_node_ip}:8777"
    if [[ "$1" = "neutron" ]]; then
      keystone endpoint-create --region myregion --service-id $service_id_neutron --publicurl "http://${controller_node_pub_ip}:9696/" --adminurl "http://${controller_node_ip}:9696/" --internalurl "http://${controller_node_ip}:9696/"
    fi
  else
    keystone endpoint-create --region myregion --service_id $service_id_ec2 --publicurl "http://${controller_node_ip}:8773/services/cloud" --adminurl "http://${controller_node_ip}:8773/services/admin" --internalurl "http://${controller_node_ip}:8773/services/cloud"
    keystone endpoint-create --region myregion --service_id $service_id_identity --publicurl "http://${controller_node_ip}:5000/v2.0" --adminurl "http://${controller_node_ip}:35357/v2.0" --internalurl "http://${controller_node_ip}:5000/v2.0"
    keystone endpoint-create --region myregion --service_id $service_id_volume --publicurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8776/v1/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $service_id_image --publicurl "http://${controller_node_ip}:9292/v2" --adminurl "http://${controller_node_ip}:9292/v2" --internalurl "http://${controller_node_ip}:9292/v2"
    keystone endpoint-create --region myregion --service_id $service_id_compute --publicurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8774/v2/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $service_id_heat --publicurl "http://${controller_node_ip}:8004/v1/\$(tenant_id)s" --adminurl "http://${controller_node_ip}:8004/v1/\$(tenant_id)s" --internalurl "http://${controller_node_ip}:8004/v1/\$(tenant_id)s"
    keystone endpoint-create --region myregion --service_id $service_id_heat_cfn --publicurl "http://${controller_node_ip}:8000/v1" --adminurl "http://${controller_node_ip}:8000/v1" --internalurl "http://${controller_node_ip}:8000/v1"
    keystone endpoint-create --region myregion --service_id $service_id_ceilometer --publicurl "http://${controller_node_ip}:8777" --adminurl "http://${controller_node_ip}:8777" --internalurl "http://${controller_node_ip}:8777"
    if [[ "$1" = "neutron" ]]; then
      keystone endpoint-create --region myregion --service-id $service_id_neutron --publicurl "http://${controller_node_ip}:9696/" --adminurl "http://${controller_node_ip}:9696/" --internalurl "http://${controller_node_ip}:9696/"
    fi
  fi

  keystone endpoint-list
}

