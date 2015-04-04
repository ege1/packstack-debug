Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }

$cinder_rab_cfg_cinder_db_pw = hiera('CONFIG_CINDER_DB_PW')
$cinder_rab_cfg_mariadb_host = hiera('CONFIG_MARIADB_HOST')

class {'cinder':
  rabbit_host         => hiera('CONFIG_AMQP_HOST'),
  rabbit_port         => hiera('CONFIG_AMQP_CLIENTS_PORT'),
  rabbit_use_ssl      => hiera('CONFIG_AMQP_ENABLE_SSL'),
  rabbit_userid       => hiera('CONFIG_AMQP_AUTH_USER'),
  rabbit_password     => hiera('CONFIG_AMQP_AUTH_PASSWORD'),
  database_connection => "mysql://cinder:${cinder_rab_cfg_cinder_db_pw}@${cinder_rab_cfg_mariadb_host}/cinder",
  verbose             => true,
  debug               => hiera('CONFIG_DEBUG_MODE'),
}
cinder_config {
  'DEFAULT/glance_host': value => hiera('CONFIG_STORAGE_HOST');
}

package { 'python-keystone':
  notify => Class['cinder::api'],
}

class { 'cinder::api':
  keystone_password  => hiera('CONFIG_CINDER_KS_PW'),
  keystone_tenant    => 'services',
  keystone_user      => 'cinder',
  keystone_auth_host => hiera('CONFIG_CONTROLLER_HOST'),
}

class { 'cinder::scheduler': }

class { 'cinder::volume': }

class { 'cinder::client': }

$cinder_config_controller_host = hiera('CONFIG_CONTROLLER_HOST')

# Cinder::Type requires keystone credentials
Cinder::Type {
  os_password    => hiera('CONFIG_CINDER_KS_PW'),
  os_tenant_name => 'services',
  os_username    => 'cinder',
  os_auth_url    => "http://${cinder_config_controller_host}:5000/v2.0/",
}

class { 'cinder::backends':
  enabled_backends => hiera_array('CONFIG_CINDER_BACKEND'),
}
$create_cinder_volume = hiera('CONFIG_CINDER_VOLUMES_CREATE')

if $create_cinder_volume == 'y' {
    class { 'cinder::setup_test_volume':
      size            => hiera('CONFIG_CINDER_VOLUMES_SIZE'),
      loopback_device => '/dev/loop2',
      volume_path     => '/var/lib/cinder',
      volume_name     => 'cinder-volumes',
    }

    # Add loop device on boot
    $el_releases = ['RedHat', 'CentOS', 'Scientific']
    if $::operatingsystem in $el_releases and $::operatingsystemmajrelease < 7 {

      file_line{ 'rc.local_losetup_cinder_volume':
        path  => '/etc/rc.d/rc.local',
        match => '^.*/var/lib/cinder/cinder-volumes.*$',
        line  => 'losetup -f /var/lib/cinder/cinder-volumes && service openstack-cinder-volume restart',
      }

      file { '/etc/rc.d/rc.local':
        mode  => '0755',
      }

    } else {

      file { 'openstack-losetup':
        path    => '/usr/lib/systemd/system/openstack-losetup.service',
        before  => Service['openstack-losetup'],
        notify  => Exec['/usr/bin/systemctl daemon-reload'],
        content => '[Unit]
Description=Setup cinder-volume loop device
DefaultDependencies=false
Before=openstack-cinder-volume.service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/sh -c \'/usr/sbin/losetup -j /var/lib/cinder/cinder-volumes | /usr/bin/grep /var/lib/cinder/cinder-volumes || /usr/sbin/losetup -f /var/lib/cinder/cinder-volumes\'
ExecStop=/usr/bin/sh -c \'/usr/sbin/losetup -j /var/lib/cinder/cinder-volumes | /usr/bin/cut -d : -f 1 | /usr/bin/xargs /usr/sbin/losetup -d\'
TimeoutSec=60
RemainAfterExit=yes

[Install]
RequiredBy=openstack-cinder-volume.service',
      }

      exec { '/usr/bin/systemctl daemon-reload':
        refreshonly => true,
        before      => Service['openstack-losetup'],
      }

      service { 'openstack-losetup':
        ensure  => running,
        enable  => true,
        require => Class['cinder::setup_test_volume'],
      }

    }
}
else {
    package {'lvm2':
      ensure => 'present',
    }
}


file_line { 'snapshot_autoextend_threshold':
  path    => '/etc/lvm/lvm.conf',
  match   => '^ *snapshot_autoextend_threshold +=.*',
  line    => '   snapshot_autoextend_threshold = 80',
  require => Package['lvm2'],
}

file_line { 'snapshot_autoextend_percent':
  path    => '/etc/lvm/lvm.conf',
  match   => '^ *snapshot_autoextend_percent +=.*',
  line    => '   snapshot_autoextend_percent = 20',
  require => Package['lvm2'],
}

cinder::backend::iscsi { 'lvm':
  iscsi_ip_address => hiera('CONFIG_STORAGE_HOST'),
  require          => Package['lvm2'],
}



cinder::type { 'iscsi':
  set_key   => 'volume_backend_name',
  set_value => 'lvm',
  require   => Class['cinder::api'],
}

class { 'cinder::ceilometer': }
class { 'cinder::backup': }

$cinder_backup_conf_ctrl_host = hiera('CONFIG_CONTROLLER_HOST')

class { 'cinder::backup::swift':
  backup_swift_url => "http://${cinder_config_controller_host}:8080/v1/AUTH_",
}

Class['cinder::api'] ~> Service['cinder-backup']


create_resources(packstack::firewall, hiera('FIREWALL_CINDER_RULES', {}))

create_resources(packstack::firewall, hiera('FIREWALL_CINDER_API_RULES', {}))

