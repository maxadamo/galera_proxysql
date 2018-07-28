# == Class: galera_proxysql::lvm
#
class galera_proxysql::lvm (
  $manage_lvm            = $::galera_proxysql::params::manage_lvm,
  $lv_size               = $::galera_proxysql::params::lv_size,
  $vg_name               = $::galera_proxysql::params::vg_name,
  $percona_major_version = $::galera_proxysql::params::percona_major_version,
  ) inherits galera_proxysql::params {

  if ($lv_size and $manage_lvm and $vg_name) {
    logical_volume { 'lv_galera':
      ensure       => present,
      volume_group => $vg_name,
      size         => "${lv_size}G",
    }

    filesystem { "/dev/mapper/${vg_name}-lv_galera":
      ensure  => present,
      fs_type => 'ext4',
      require => Logical_volume['lv_galera']
    }

    file { '/var/lib/mysql':
      ensure  => directory,
      mode    => '0755',
      owner   => mysql,
      group   => mysql,
      require => Package["Percona-XtraDB-Cluster-full-${percona_major_version}"];
    }

    mount { '/var/lib/mysql':
      ensure  => mounted,
      fstype  => 'ext4',
      atboot  => true,
      device  => "/dev/mapper/${vg_name}-lv_galera",
      require => [
        File['/var/lib/mysql'],
        Filesystem["/dev/mapper/${vg_name}-lv_galera"]
      ],
      notify  => Exec['fix_datadir_permissions'];
    }

    exec { 'fix_datadir_permissions':
      command => 'chown mysql:mysql /var/lib/mysql',
      path    => '/usr/bin:/usr/sbin:/bin',
      unless  => 'stat -c "%U%G" /var/lib/mysql/|grep "mysqlmysql"';
    }
  }

}
