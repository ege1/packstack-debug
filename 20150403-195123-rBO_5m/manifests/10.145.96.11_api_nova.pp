Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }


require 'keystone::python'
class { 'nova::api':
  enabled                              => true,
  auth_host                            => hiera('CONFIG_CONTROLLER_HOST'),
  admin_password                       => hiera('CONFIG_NOVA_KS_PW'),
  neutron_metadata_proxy_shared_secret => hiera('CONFIG_NEUTRON_METADATA_PW_UNQUOTED'),
}

Package<| title == 'nova-common' |> -> Class['nova::api']

create_resources(packstack::firewall, hiera('FIREWALL_NOVA_API_RULES', {}))



$nova_neutron_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')

class { 'nova::network::neutron':
  neutron_admin_password    => hiera('CONFIG_NEUTRON_KS_PW'),
  neutron_auth_strategy     => 'keystone',
  neutron_url               => "http://${nova_neutron_cfg_ctrl_host}:9696",
  neutron_admin_tenant_name => 'services',
  neutron_admin_auth_url    => "http://${nova_neutron_cfg_ctrl_host}:35357/v2.0",
  neutron_region_name       => hiera('CONFIG_KEYSTONE_REGION'),
}

class { 'nova::compute::neutron':
  libvirt_vif_driver => hiera('CONFIG_NOVA_LIBVIRT_VIF_DRIVER'),
}


$private_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_SECRET'),
}
$public_key = {
  type => hiera('NOVA_MIGRATION_KEY_TYPE'),
  key  => hiera('NOVA_MIGRATION_KEY_PUBLIC'),
}

$nova_common_rabbitmq_cfg_storage_host = hiera('CONFIG_STORAGE_HOST')

class { 'nova':
  glance_api_servers => "${nova_common_rabbitmq_cfg_storage_host}:9292",
  rabbit_host        => hiera('CONFIG_AMQP_HOST'),
  rabbit_port        => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl     => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid      => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password    => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  verbose            => true,
  debug              => hiera('CONFIG_DEBUG_MODE'),
  nova_public_key    => $public_key,
  nova_private_key   => $private_key,
}
$config_use_neutron = hiera('CONFIG_NEUTRON_INSTALL')

if $config_use_neutron == 'y' {
    $default_floating_pool = 'public'
} else {
    $default_floating_pool = 'nova'
}

# Ensure Firewall changes happen before nova services start
# preventing a clash with rules being set by nova-compute and nova-network
Firewall <| |> -> Class['nova']

nova_config{
  'DEFAULT/sql_connection':        value => hiera('CONFIG_NOVA_SQL_CONN_PW');
  'DEFAULT/metadata_host':         value => hiera('CONFIG_CONTROLLER_HOST');
  'DEFAULT/default_floating_pool': value => $default_floating_pool;
}
