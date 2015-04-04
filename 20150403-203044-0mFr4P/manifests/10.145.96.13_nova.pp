Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }


package{ 'python-cinderclient':
  before => Class['nova']
}

# Install the private key to be used for live migration.  This needs to be
# configured into libvirt/live_migration_uri in nova.conf.
file { '/etc/nova/ssh':
  ensure => directory,
  owner  => root,
  group  => root,
  mode   => '0700',
}

file { '/etc/nova/ssh/nova_migration_key':
  content => hiera('NOVA_MIGRATION_KEY_SECRET'),
  mode    => '0600',
  owner   => root,
  group   => root,
  require => File['/etc/nova/ssh'],
}

nova_config{
  'DEFAULT/volume_api_class':
    value => 'nova.volume.cinder.API';
  'libvirt/live_migration_uri':
    value => hiera('CONFIG_NOVA_COMPUTE_MIGRATE_URL');
}

$config_horizon_ssl = hiera('CONFIG_HORIZON_SSL')

$vncproxy_proto = $config_horizon_ssl ? {
  true    => 'https',
  false   => 'http',
  default => 'http',
}

if ($::fqdn == '' or $::fqdn =~ /localhost/) {
  # For cases where FQDNs have not been correctly set
  $vncproxy_server = choose_my_ip(hiera('HOST_LIST'))
} else {
  $vncproxy_server = $::fqdn
}

class { 'nova::compute':
  enabled                       => true,
  vncproxy_host                 => hiera('CONFIG_CONTROLLER_HOST'),
  vncproxy_protocol             => $vncproxy_proto,
  vncserver_proxyclient_address => $vncproxy_server,
  compute_manager               => hiera('CONFIG_NOVA_COMPUTE_MANAGER'),
}

# Tune the host with a virtual hosts profile
package { 'tuned':
  ensure => present,
}

service { 'tuned':
  ensure  => running,
  require => Package['tuned'],
}

exec { 'tuned-virtual-host':
  unless  => '/usr/sbin/tuned-adm active | /bin/grep virtual-host',
  command => '/usr/sbin/tuned-adm profile virtual-host',
  require => Service['tuned'],
}
create_resources(packstack::firewall, hiera('FIREWALL_NOVA_QEMU_MIG_RULES_10.145.96.13', {}))

Firewall <| |> -> Class['nova::compute::libvirt']

# Ensure Firewall changes happen before libvirt service start
# preventing a clash with rules being set by libvirt

if $::is_virtual == 'true' {
  $libvirt_virt_type = 'qemu'
  $libvirt_cpu_mode = 'none'
} else {
  $libvirt_virt_type = 'kvm'
}

# We need to preferably install qemu-kvm-rhev
exec { 'qemu-kvm':
  path    => '/usr/bin',
  command => 'yum install -y -d 0 -e 0 qemu-kvm',
  onlyif  => 'yum install -y -d 0 -e 0 qemu-kvm-rhev &> /dev/null && exit 1 || exit 0',
  before  => Class['nova::compute::libvirt'],
}

class { 'nova::compute::libvirt':
  libvirt_virt_type        => $libvirt_virt_type,
  libvirt_cpu_mode         => $libvirt_cpu_mode,
  vncserver_listen         => '0.0.0.0',
  migration_support        => true,
  libvirt_inject_partition => '-1',
}

exec { 'load_kvm':
  user    => 'root',
  command => '/bin/sh /etc/sysconfig/modules/kvm.modules',
  onlyif  => '/usr/bin/test -e /etc/sysconfig/modules/kvm.modules',
}

Class['nova::compute'] -> Exec['load_kvm']

file_line { 'libvirt-guests':
  path    => '/etc/sysconfig/libvirt-guests',
  line    => 'ON_BOOT=ignore',
  match   => '^[\s#]*ON_BOOT=.*',
  require => Class['nova::compute::libvirt'],
}

# Remove libvirt's default network (usually virbr0) as it's unnecessary and
# can be confusing
exec {'virsh-net-destroy-default':
  onlyif  => '/usr/bin/virsh net-list | grep default',
  command => '/usr/bin/virsh net-destroy default',
  require => Service['libvirt'],
}

exec {'virsh-net-undefine-default':
  onlyif  => '/usr/bin/virsh net-list --inactive | grep default',
  command => '/usr/bin/virsh net-undefine default',
  require => Exec['virsh-net-destroy-default'],
}

class { 'ceilometer':
    metering_secret => hiera('CONFIG_CEILOMETER_SECRET'),
    rabbit_host     => hiera('CONFIG_AMQP_HOST'),
    rabbit_port     => hiera('CONFIG_AMQP_CLIENTS_PORT'),
    rabbit_use_ssl  => hiera('CONFIG_AMQP_ENABLE_SSL'),
    rabbit_userid   => hiera('CONFIG_AMQP_AUTH_USER'),
    rabbit_password => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
    verbose         => true,
    debug           => hiera('CONFIG_DEBUG_MODE'),
    # for some strange reason ceilometer needs to be in nova group
    require         => Package['nova-common'],
}

$nova_ceil_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')

class { 'ceilometer::agent::auth':
  auth_url      => "http://${nova_ceil_cfg_ctrl_host}:35357/v2.0",
  auth_password => hiera('CONFIG_CEILOMETER_KS_PW'),
}

class { 'ceilometer::agent::compute': }


create_resources(packstack::firewall, hiera('FIREWALL_NOVA_COMPUTE_RULES', {}))




create_resources(sshkey, hiera('SSH_KEYS', {}))


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
