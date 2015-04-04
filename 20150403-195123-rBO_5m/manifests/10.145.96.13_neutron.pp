Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }

$neutron_db_host         = hiera('CONFIG_MARIADB_HOST')
$neutron_db_name         = hiera('CONFIG_NEUTRON_L2_DBNAME')
$neutron_db_user         = 'neutron'
$neutron_db_password     = hiera('CONFIG_NEUTRON_DB_PW')
$neutron_sql_connection  = "mysql://${neutron_db_user}:${neutron_db_password}@${neutron_db_host}/${neutron_db_name}"
$neutron_user_password   = hiera('CONFIG_NEUTRON_KS_PW')



class { 'neutron':
  rabbit_host           => hiera('CONFIG_AMQP_HOST'),
  rabbit_port           => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl        => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_user           => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password       => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  core_plugin           => hiera('CONFIG_NEUTRON_CORE_PLUGIN'),
  allow_overlapping_ips => true,
  service_plugins       => hiera_array('SERVICE_PLUGINS'),
  verbose               => true,
  debug                 => hiera('CONFIG_DEBUG_MODE'),
}

class { 'neutron::agents::l3':
  interface_driver        => hiera('CONFIG_NEUTRON_L3_INTERFACE_DRIVER'),
  external_network_bridge => hiera('CONFIG_NEUTRON_L3_EXT_BRIDGE'),
  debug                   => hiera('CONFIG_DEBUG_MODE'),
}

sysctl::value { 'net.ipv4.ip_forward':
  value => '1',
}


$agent_service = 'neutron-ovs-agent-service'

$config_neutron_ovs_bridge = hiera('CONFIG_NEUTRON_OVS_BRIDGE')

vs_bridge { $config_neutron_ovs_bridge:
  ensure  => present,
  require => Service[$agent_service],
}


$cfg_neutron_ovs_host = '10.145.96.13'
$ovs_agent_vxlan_cfg_neut_ovs_tun_if = hiera('CONFIG_NEUTRON_OVS_TUNNEL_IF',undef)

if $ovs_agent_vxlan_cfg_neut_ovs_tun_if != '' {
  $iface = regsubst($ovs_agent_vxlan_cfg_neut_ovs_tun_if, '[\.\-\:]', '_', 'G')
  $localip = inline_template("<%= scope.lookupvar('::ipaddress_${iface}') %>")
} else {
  $localip = $cfg_neutron_ovs_host
}

class { 'neutron::agents::ml2::ovs':
  bridge_uplinks   => hiera_array('CONFIG_NEUTRON_OVS_BRIDGE_IFACES'),
  bridge_mappings  => hiera_array('CONFIG_NEUTRON_OVS_BRIDGE_MAPPINGS'),
  enable_tunneling => hiera('CONFIG_NEUTRON_OVS_TUNNELING'),
  tunnel_types     => hiera_array('CONFIG_NEUTRON_OVS_TUNNEL_TYPES'),
  local_ip         => $localip,
  vxlan_udp_port   => hiera('CONFIG_NEUTRON_OVS_VXLAN_UDP_PORT',undef),
  l2_population    => hiera('CONFIG_NEUTRON_USE_L2POPULATION'),
}



class { 'packstack::neutron::bridge': }


class { 'neutron::agents::dhcp':
  interface_driver => hiera('CONFIG_NEUTRON_DHCP_INTERFACE_DRIVER'),
  debug            => hiera('CONFIG_DEBUG_MODE'),
}

create_resources(packstack::firewall, hiera('FIREWALL_NEUTRON_DHCPIN_RULES', {}))

create_resources(packstack::firewall, hiera('FIREWALL_NEUTRON_DHCPOUT_RULES', {}))


$neutron_metadata_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')

class { 'neutron::agents::metadata':
  auth_password => hiera('CONFIG_NEUTRON_KS_PW'),
  auth_url      => "http://${neutron_metadata_cfg_ctrl_host}:35357/v2.0",
  auth_region   => hiera('CONFIG_KEYSTONE_REGION'),
  shared_secret => hiera('CONFIG_NEUTRON_METADATA_PW'),
  metadata_ip   => hiera('CONFIG_CONTROLLER_HOST'),
  debug         => hiera('CONFIG_DEBUG_MODE'),
}

