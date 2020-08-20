# == Class: galera_proxysql::lvm
#
class galera_proxysql::lvm (
  $manage_lvm,
  $lv_size,
  $vg_name,
  $percona_major_version,
) {

  assert_private("this class should be called only by ${module_name}")

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
      mode    => '0751',
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
