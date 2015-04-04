Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }

include packstack::apache_common

package { ['nagios', 'nagios-plugins-nrpe']:
  ensure => present,
  before => Class['nagios_configs'],
}

# We need to preferably install nagios-plugins-ping
exec { 'nagios-plugins-ping':
  path    => '/usr/bin',
  command => 'yum install -y -d 0 -e 0 monitoring-plugins-ping',
  onlyif  => 'yum install -y -d 0 -e 0 nagios-plugins-ping &> /dev/null && exit 1 || exit 0',
  before  => Class['nagios_configs']
}

class nagios_configs(){
  file { ['/etc/nagios/nagios_command.cfg', '/etc/nagios/nagios_host.cfg']:
    ensure => 'present',
    mode   => '0644',
    owner  => 'nagios',
    group  => 'nagios',
  }

  # Remove the entry for localhost, it contains services we're not
  # monitoring
  file { ['/etc/nagios/objects/localhost.cfg']:
    ensure  => 'present',
    content => '',
  }

  file_line { 'nagios_host':
    path => '/etc/nagios/nagios.cfg',
    line => 'cfg_file=/etc/nagios/nagios_host.cfg',
  }

  file_line { 'nagios_command':
    path => '/etc/nagios/nagios.cfg',
    line => 'cfg_file=/etc/nagios/nagios_command.cfg',
  }

  file_line { 'nagios_service':
    path => '/etc/nagios/nagios.cfg',
    line => 'cfg_file=/etc/nagios/nagios_service.cfg',
  }

  nagios_command { 'check_nrpe':
    command_line => '/usr/lib64/nagios/plugins/check_nrpe -H $HOSTADDRESS$ -c $ARG1$',
  }

  $cfg_nagios_pw = hiera('CONFIG_NAGIOS_PW')

  exec { 'nagiospasswd':
    command => "/usr/bin/htpasswd -b /etc/nagios/passwd nagiosadmin ${cfg_nagios_pw}",
  }

  $nagios_cfg_ks_adm_pw = hiera('CONFIG_KEYSTONE_ADMIN_PW')
  $nagios_cfg_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')

  file { '/etc/nagios/keystonerc_admin':
      ensure  => 'present',
      owner   => 'nagios',
      mode    => '0600',
      content => "export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_PASSWORD=${nagios_cfg_ks_adm_pw}
export OS_AUTH_URL=http://${nagios_cfg_ctrl_host}:35357/v2.0/ ",
  }

  nagios_host { '10.145.96.11': , use => 'linux-server', address => '10.145.96.11'}
nagios_host { '10.145.96.13': , use => 'linux-server', address => '10.145.96.13'}
nagios_host { '10.145.96.12': , use => 'linux-server', address => '10.145.96.12'}
file{"/usr/lib64/nagios/plugins/keystone-user-list":mode => 755, owner => "nagios", seltype => "nagios_unconfined_plugin_exec_t", content => template("packstack/keystone-user-list.erb"),}
nagios_command {"keystone-user-list": command_line => "/usr/lib64/nagios/plugins/keystone-user-list",}
file{"/usr/lib64/nagios/plugins/glance-index":mode => 755, owner => "nagios", seltype => "nagios_unconfined_plugin_exec_t", content => template("packstack/glance-index.erb"),}
nagios_command {"glance-index": command_line => "/usr/lib64/nagios/plugins/glance-index",}
file{"/usr/lib64/nagios/plugins/nova-list":mode => 755, owner => "nagios", seltype => "nagios_unconfined_plugin_exec_t", content => template("packstack/nova-list.erb"),}
nagios_command {"nova-list": command_line => "/usr/lib64/nagios/plugins/nova-list",}
file{"/usr/lib64/nagios/plugins/cinder-list":mode => 755, owner => "nagios", seltype => "nagios_unconfined_plugin_exec_t", content => template("packstack/cinder-list.erb"),}
nagios_command {"cinder-list": command_line => "/usr/lib64/nagios/plugins/cinder-list",}
file{"/usr/lib64/nagios/plugins/swift-list":mode => 755, owner => "nagios", seltype => "nagios_unconfined_plugin_exec_t", content => template("packstack/swift-list.erb"),}
nagios_command {"swift-list": command_line => "/usr/lib64/nagios/plugins/swift-list",}
file { '/etc/nagios/nagios_service.cfg': 
ensure => present, mode => 644,
owner => 'nagios', group => 'nagios',
before => Service['nagios'],
content => 'define service {
	check_command	check_nrpe!load5
	host_name	10.145.96.11
	name	load5-10.145.96.11
	normal_check_interval	5
	service_description	5 minute load average
	use	generic-service
	}
define service {
	check_command	check_nrpe!df_var
	host_name	10.145.96.11
	name	df_var-10.145.96.11
	service_description	Percent disk space used on /var
	use	generic-service
	}
define service {
	check_command	check_nrpe!load5
	host_name	10.145.96.13
	name	load5-10.145.96.13
	normal_check_interval	5
	service_description	5 minute load average
	use	generic-service
	}
define service {
	check_command	check_nrpe!df_var
	host_name	10.145.96.13
	name	df_var-10.145.96.13
	service_description	Percent disk space used on /var
	use	generic-service
	}
define service {
	check_command	check_nrpe!load5
	host_name	10.145.96.12
	name	load5-10.145.96.12
	normal_check_interval	5
	service_description	5 minute load average
	use	generic-service
	}
define service {
	check_command	check_nrpe!df_var
	host_name	10.145.96.12
	name	df_var-10.145.96.12
	service_description	Percent disk space used on /var
	use	generic-service
	}
define service {
	check_command	keystone-user-list
	host_name	10.145.96.11
	name	keystone-user-list
	normal_check_interval	5
	service_description	number of keystone users
	use	generic-service
	}
define service {
	check_command	glance-index
	host_name	10.145.96.11
	name	glance-index
	normal_check_interval	5
	service_description	number of glance images
	use	generic-service
	}
define service {
	check_command	nova-list
	host_name	10.145.96.11
	name	nova-list
	normal_check_interval	5
	service_description	number of nova vm instances
	use	generic-service
	}
define service {
	check_command	cinder-list
	host_name	10.145.96.11
	name	cinder-list
	normal_check_interval	5
	service_description	number of cinder volumes
	use	generic-service
	}
define service {
	check_command	swift-list
	host_name	10.145.96.11
	name	swift-list
	normal_check_interval	5
	service_description	number of swift containers
	use	generic-service
	}
'}
}

class { 'nagios_configs':
  notify => [Service['nagios'], Service['httpd']],
}

include concat::setup

class { 'apache':
  purge_configs => false,
}

class { 'apache::mod::php': }

service { ['nagios']:
  ensure    => running,
  enable    => true,
  hasstatus => true,
}

firewall { '001 nagios incoming':
  proto    => 'tcp',
  dport    => ['80'],
  action   => 'accept',
}

# ensure that we won't stop listening on 443 if horizon has ssl enabled
if hiera('CONFIG_HORIZON_SSL') {
  apache::listen { '443': }
}
