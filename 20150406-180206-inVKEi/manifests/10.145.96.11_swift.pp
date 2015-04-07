Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }


package { 'curl': ensure => present }

class { 'memcached': }

class { 'swift::proxy':
  proxy_local_net_ip => hiera('CONFIG_CONTROLLER_HOST'),
  pipeline           => [
    'catch_errors',
    'bulk',
    'healthcheck',
    'cache',
    'crossdomain',
    'ratelimit',
    'authtoken',
    'keystone',
    'staticweb',
    'tempurl',
    'slo',
    'formpost',
    'account_quotas',
    'container_quotas',
    'proxy-server'
  ],
  account_autocreate => true,
}

# configure all of the middlewares
class { [
  'swift::proxy::catch_errors',
  'swift::proxy::healthcheck',
  'swift::proxy::cache',
  'swift::proxy::crossdomain',
  'swift::proxy::staticweb',
  'swift::proxy::tempurl',
  'swift::proxy::account_quotas',
  'swift::proxy::formpost',
  'swift::proxy::slo',
  'swift::proxy::container_quotas'
]: }

class { 'swift::proxy::bulk':
  max_containers_per_extraction => 10000,
  max_failed_extractions        => 1000,
  max_deletes_per_request       => 10000,
  yield_frequency               => 60,
}

class { 'swift::proxy::ratelimit':
  clock_accuracy         => 1000,
  max_sleep_time_seconds => 60,
  log_sleep_time_seconds => 0,
  rate_buffer_seconds    => 5,
  account_ratelimit      => 0
}

class { 'swift::proxy::keystone':
  operator_roles => ['admin', 'SwiftOperator'],
}

class { 'swift::proxy::authtoken':
  admin_user        => 'swift',
  admin_tenant_name => 'services',
  admin_password    => hiera('CONFIG_SWIFT_KS_PW'),
  # assume that the controller host is the swift api server
  auth_host         => hiera('CONFIG_CONTROLLER_HOST'),
}

create_resources(packstack::firewall, hiera('FIREWALL_SWIFT_PROXY_RULES', {}))



# install all swift storage servers together
class { 'swift::storage::all':
  storage_local_net_ip => hiera('CONFIG_CONTROLLER_HOST'),
  allow_versions       => true,
  require              => Class['swift'],
}

if (!defined(File['/srv/node'])) {
  file { '/srv/node':
    ensure  => directory,
    owner   => 'swift',
    group   => 'swift',
    require => Package['openstack-swift'],
  }
}

swift::ringsync{ ['account', 'container', 'object']:
  ring_server => hiera('CONFIG_CONTROLLER_HOST'),
  before      => Class['swift::storage::all'],
  require     => Class['swift'],
}


swift::storage::loopback { 'swiftloopback':
  base_dir     => '/srv/loopback-device',
  mnt_base_dir => '/srv/node',
  require      => Class['swift'],
  fstype       => hiera('CONFIG_SWIFT_STORAGE_FSTYPE'),
  seek         => hiera('CONFIG_SWIFT_STORAGE_SEEK'),
}


create_resources(packstack::firewall, hiera('FIREWALL_SWIFT_STORAGE_RULES', {}))



class { 'ssh::server::install': }

Class['swift'] -> Service <| |>

class { 'swift':
  # not sure how I want to deal with this shared secret
  swift_hash_suffix => hiera('CONFIG_SWIFT_HASH'),
  package_ensure    => latest,
}
