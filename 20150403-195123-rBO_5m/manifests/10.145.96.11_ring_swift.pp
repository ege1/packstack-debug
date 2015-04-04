Exec { timeout => hiera('DEFAULT_EXEC_TIMEOUT') }


class { 'swift::ringbuilder':
  part_power     => '18',
  replicas       => hiera('CONFIG_SWIFT_STORAGE_REPLICAS'),
  min_part_hours => 1,
  require        => Class['swift'],
}

# sets up an rsync db that can be used to sync the ring DB
class { 'swift::ringserver':
  local_net_ip => hiera('CONFIG_CONTROLLER_HOST'),
}

if str2bool($::selinux) {
  selboolean { 'rsync_export_all_ro':
    value      => on,
    persistent => true,
  }
}

@@ring_object_device { "10.145.96.11:6000/swiftloopback":
  zone   => 1,
  weight => 10, }

@@ring_container_device { "10.145.96.11:6001/swiftloopback":
  zone   => 1,
  weight => 10, }

@@ring_account_device { "10.145.96.11:6002/swiftloopback":
  zone   => 1,
  weight => 10, }


class { 'ssh::server::install': }

Class['swift'] -> Service <| |>

class { 'swift':
  # not sure how I want to deal with this shared secret
  swift_hash_suffix => hiera('CONFIG_SWIFT_HASH'),
  package_ensure    => latest,
}
