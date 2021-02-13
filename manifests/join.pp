# == Class: galera_proxysql::join
#
# This Class manages services
#
class galera_proxysql::join (
  $percona_major_version,
  Sensitive $monitor_password,
  Sensitive $root_password,
  Sensitive $sst_password,
  $galera_hosts,
  $proxysql_hosts,
  $proxysql_vip,
  $manage_lvm,
  $manage_firewall
) {

  assert_private("this class should be called only by ${module_name}")

  $joined_file = '/var/lib/mysql/gvwstate.dat'

  $file_list = [
    '/usr/bin/galera_wizard.py', '/root/galera_params.ini', '/etc/my.cnf',
    '/root/.my.cnf', '/etc/my.cnf.d/server.cnf', '/etc/my.cnf.d/client.cnf',
    '/etc/my.cnf.d/wsrep.cnf', '/etc/my.cnf'
  ]

  $common_require = [
    File[$file_list],
    File_line['mysql_systemd'],
    Package["Percona-XtraDB-Cluster-full-${percona_major_version}"]
  ]

  if ($manage_lvm) {
    $lvm_require = $common_require + Mount['/var/lib/mysql']
  } else {
    $lvm_require = $common_require
  }

  if ($manage_firewall) {
    $require = $lvm_require + Class['galera_proxysql::firewall']
  } else {
    $require = $lvm_require
  }

  unless defined(Exec['bootstrap_or_join']) {
    exec { 'bootstrap_or_join':
      command => 'galera_wizard.py -bn -f || galera_wizard.py -jn -f',
      path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
      creates => $joined_file,
      returns => [0,1],
      require => $require;
    }
  }

  if ($facts['galera_joined_exist'] and $facts['galera_status'] != '200') {
    unless defined(Exec['join_existing']) {
      exec { 'join_existing':
        command => 'galera_wizard.py -je',
        path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
        returns => [0,1],
        require => $require;
      }
    }
  } else {
    unless defined(Exec['join_existing']) {
      exec { 'join_existing':
        command     => 'echo',
        path        => '/usr/bin:/bin',
        refreshonly => true;
      }
    }
  }

  if ($facts['galera_joined_exist'] and $facts['galera_status'] == '200') {
    galera_proxysql::create::sys_user {
      'sstuser':
        galera_hosts   => $galera_hosts,
        proxysql_hosts => $proxysql_hosts,
        proxysql_vip   => $proxysql_vip,
        dbpass         => $sst_password;
      'monitor':
        galera_hosts   => $galera_hosts,
        proxysql_hosts => $proxysql_hosts,
        proxysql_vip   => $proxysql_vip,
        dbpass         => $monitor_password;
    }
  }

}
