Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }

$mongodb_host = hiera('CONFIG_MONGODB_HOST')

class { 'mongodb::server':
  smallfiles => true,
  bind_ip    => [$mongodb_host],
}

create_resources(packstack::firewall, hiera('FIREWALL_MONGODB_RULES', {}))

