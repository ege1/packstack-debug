Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }

$heat_rabbitmq_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')
$heat_rabbitmq_cfg_heat_db_pw = hiera('CONFIG_HEAT_DB_PW')
$heat_rabbitmq_cfg_mariadb_host = hiera('CONFIG_MARIADB_HOST')

class { 'heat':
  keystone_host       => $heat_rabbitmq_cfg_ctrl_host,
  keystone_password   => hiera('CONFIG_HEAT_KS_PW'),
  auth_uri            => "http://${heat_rabbitmq_cfg_ctrl_host}:35357/v2.0",
  keystone_ec2_uri    => "http://${heat_rabbitmq_cfg_ctrl_host}:35357/v2.0",
  rpc_backend         => 'heat.openstack.common.rpc.impl_kombu',
  rabbit_host         => hiera('CONFIG_AMQP_HOST'),
  rabbit_port         => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl      => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid       => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password     => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  verbose             => true,
  debug               => hiera('CONFIG_DEBUG_MODE'),
  database_connection => "mysql://heat:${heat_rabbitmq_cfg_heat_db_pw}@${heat_rabbitmq_cfg_mariadb_host}/heat",
}

class { 'heat::api': }

$heat_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')

class { 'heat::engine':
  heat_metadata_server_url      => "http://${heat_cfg_ctrl_host}:8000",
  heat_waitcondition_server_url => "http://${heat_cfg_ctrl_host}:8000/v1/waitcondition",
  heat_watch_server_url         => "http://${heat_cfg_ctrl_host}:8003",
  auth_encryption_key           => hiera('CONFIG_HEAT_AUTH_ENC_KEY'),
  configure_delegated_roles     => false,
}

keystone_user_role { 'admin@admin':
  ensure  => present,
  roles   => ['admin', '_member_', 'heat_stack_owner'],
  require => Class['heat::engine'],
}

class { 'heat::keystone::domain':
  auth_url          => "http://${heat_cfg_ctrl_host}:35357/v2.0",
  keystone_admin    => 'admin',
  keystone_password => hiera('CONFIG_KEYSTONE_ADMIN_PW'),
  keystone_tenant   => 'admin',
  domain_name       => hiera('CONFIG_HEAT_DOMAIN'),
  domain_admin      => hiera('CONFIG_HEAT_DOMAIN_ADMIN'),
  domain_password   => hiera('CONFIG_HEAT_DOMAIN_PASSWORD'),
}

# heat::keystone::auth
class { 'heat::keystone::auth':
  region                    => hiera('CONFIG_KEYSTONE_REGION'),
  password                  => hiera('CONFIG_HEAT_KS_PW'),
  public_address            => hiera('CONFIG_CONTROLLER_HOST'),
  admin_address             => hiera('CONFIG_CONTROLLER_HOST'),
  internal_address          => hiera('CONFIG_CONTROLLER_HOST'),
  configure_delegated_roles => true,
}

$is_heat_cfn_install = hiera('CONFIG_HEAT_CFN_INSTALL')

if $is_heat_cfn_install == 'y' {
  # heat::keystone::cfn
  class { "heat::keystone::auth_cfn":
    password         => hiera('CONFIG_HEAT_KS_PW'),
    public_address   => hiera('CONFIG_CONTROLLER_HOST'),
    admin_address    => hiera('CONFIG_CONTROLLER_HOST'),
    internal_address => hiera('CONFIG_CONTROLLER_HOST'),
  }
}
create_resources(packstack::firewall, hiera('FIREWALL_HEAT_RULES', {}))

