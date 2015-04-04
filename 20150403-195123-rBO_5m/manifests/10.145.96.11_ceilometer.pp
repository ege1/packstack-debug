Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }

class { 'ceilometer':
  metering_secret => hiera('CONFIG_CEILOMETER_SECRET'),
  verbose         => true,
  debug           => hiera('CONFIG_DEBUG_MODE'),
  rabbit_host     => hiera('CONFIG_AMQP_HOST'),
  rabbit_port     => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl  => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid   => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
}
$config_mongodb_host = hiera('CONFIG_MONGODB_HOST')

$config_ceilometer_coordination_backend = hiera('CONFIG_CEILOMETER_COORDINATION_BACKEND')

if $config_ceilometer_coordination_backend == 'redis' {
  $redis_host = hiera('CONFIG_REDIS_MASTER_HOST')
  $redis_port = hiera('CONFIG_REDIS_PORT')
  $sentinel_host = hiera('CONFIG_REDIS_SENTINEL_CONTACT_HOST')
  $sentinel_fallbacks = hiera('CONFIG_REDIS_SENTINEL_FALLBACKS')
  if $sentinel_host != '' {
    $master_name = hiera('CONFIG_REDIS_MASTER_NAME')
    $sentinel_port = hiera('CONFIG_REDIS_SENTINEL_PORT')
    $base_coordination_url = "redis://${sentinel_host}:${sentinel_port}?sentinel=${master_name}"
    if $sentinel_fallbacks != '' {
      $coordination_url = "${base_coordination_url}&${sentinel_fallbacks}"
    } else {
      $coordination_url = $base_coordination_url
    }
  } else {
    $coordination_url = "redis://${redis_host}:${redis_port}"
  }
} else {
  $coordination_url = ''
}

class { 'ceilometer::db':
  database_connection => "mongodb://${config_mongodb_host}:27017/ceilometer",
}

class { 'ceilometer::collector': }

class { 'ceilometer::agent::notification': }

$config_controller_host = hiera('CONFIG_CONTROLLER_HOST')

class { 'ceilometer::agent::auth':
  auth_url      => "http://${config_controller_host}:35357/v2.0",
  auth_password => hiera('CONFIG_CEILOMETER_KS_PW'),
}

class { 'ceilometer::agent::central':
  coordination_url => $coordination_url,
}

class { 'ceilometer::alarm::notifier':}

class { 'ceilometer::alarm::evaluator':
  coordination_url => $coordination_url,
}

class { 'ceilometer::api':
  keystone_host     => hiera('CONFIG_CONTROLLER_HOST'),
  keystone_password => hiera('CONFIG_CEILOMETER_KS_PW'),
}
create_resources(packstack::firewall, hiera('FIREWALL_CEILOMETER_RULES', {}))

