Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }


# Package mariadb-server conflicts with mariadb-galera-server
package { 'mariadb-server':
  ensure => absent,
}

class { 'mysql::server':
  package_name     => 'mariadb-galera-server',
  restart          => true,
  root_password    => hiera('CONFIG_MARIADB_PW'),
  require          => Package['mariadb-server'],
  override_options => {
    'mysqld' => { bind_address           => '0.0.0.0',
                  default_storage_engine => 'InnoDB',
                  max_connections        => '1024',
                  open_files_limit       => '-1',
    }
  }
}

# deleting database users for security
# this is done in mysql::server::account_security but has problems
# when there is no fqdn, so we're defining a slightly different one here
mysql_user { [ 'root@127.0.0.1', 'root@::1', '@localhost', '@%' ]:
  ensure  => 'absent',
  require => Class['mysql::server'],
}

if ($::fqdn != '' and $::fqdn != 'localhost') {
  mysql_user { [ "root@${::fqdn}", "@${::fqdn}"]:
    ensure  => 'absent',
    require => Class['mysql::server'],
  }
}
if ($::fqdn != $::hostname and $::hostname != 'localhost') {
  mysql_user { ["root@${::hostname}", "@${::hostname}"]:
    ensure  => 'absent',
    require => Class['mysql::server'],
  }
}


class { 'keystone::db::mysql':
  user          => 'keystone_admin',
  password      => hiera('CONFIG_KEYSTONE_DB_PW'),
  allowed_hosts => '%',
  charset       => 'utf8',
}

class { 'nova::db::mysql':
  password      => hiera('CONFIG_NOVA_DB_PW'),
  host          => '%',
  allowed_hosts => '%',
  charset       => 'utf8',
}

class { 'cinder::db::mysql':
  password      => hiera('CONFIG_CINDER_DB_PW'),
  host          => '%',
  allowed_hosts => '%',
  charset       => 'utf8',
}

class { 'glance::db::mysql':
  password      => hiera('CONFIG_GLANCE_DB_PW'),
  host          => '%',
  allowed_hosts => '%',
  charset       => 'utf8',
}

class { 'neutron::db::mysql':
  password      => hiera('CONFIG_NEUTRON_DB_PW'),
  host          => '%',
  allowed_hosts => '%',
  dbname        => hiera('CONFIG_NEUTRON_L2_DBNAME'),
  charset       => 'utf8',
}

class { 'heat::db::mysql':
  password      => hiera('CONFIG_HEAT_DB_PW'),
  host          => '%',
  allowed_hosts => '%',
  charset       => 'utf8',
}

class { 'sahara::db::mysql':
  password      => hiera('CONFIG_SAHARA_DB_PW'),
  host          => '%',
  allowed_hosts => '%',
}

create_resources(packstack::firewall, hiera('FIREWALL_MARIADB_RULES', {}))

