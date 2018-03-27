
# == Class: galera_maxscale::join
#
# This Class manages services
#
class galera_maxscale::join (
  $percona_major_version = $::galera_maxscale::params::percona_major_version,
  $monitor_password      = $::galera_maxscale::params::monitor_password,
  $root_password         = $::galera_maxscale::params::root_password,
  $sst_password          = $::galera_maxscale::params::sst_password,
  $proxysql_password     = $::galera_maxscale::params::proxysql_password,
  $galera_hosts          = $::galera_maxscale::params::galera_hosts,
  $proxysql_hosts        = $::galera_maxscale::params::proxysql_hosts,
  $proxysql_vip          = $::galera_maxscale::params::proxysql_vip,
  $manage_lvm            = $::galera_maxscale::params::manage_lvm,
  ) inherits galera_maxscale::params {

  $joined_file = '/var/lib/mysql/gvwstate.dat'

  $file_list = [
    '/usr/bin/galera_wizard.py', '/root/galera_params.py', '/etc/my.cnf',
    '/root/.my.cnf', '/etc/my.cnf.d/server.cnf', '/etc/my.cnf.d/client.cnf',
    '/etc/my.cnf.d/wsrep.cnf', '/etc/my.cnf'
  ]

  if ($manage_lvm) {
    $require_list = [
      File[$file_list],
      File_line['mysql_systemd'],
      Package["Percona-XtraDB-Cluster-full-${percona_major_version}"],
      Mount['/var/lib/mysql']
    ]
  } else {
    $require_list = [
      File[$file_list],
      File_line['mysql_systemd'],
      Package["Percona-XtraDB-Cluster-full-${percona_major_version}"]
    ]
  }

  unless defined(Exec['bootstrap_or_join']) {
    exec { 'bootstrap_or_join':
      command => 'galera_wizard.py -bn -f || galera_wizard.py -jn -f',
      path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
      creates => $joined_file,
      returns => [0,1],
      require => $require_list;
    }
  }

  if ($::galera_joined_exist and $::galera_status != '200') {
    unless defined(Exec['join_existing']) {
      exec { 'join_existing':
        command => 'galera_wizard.py -je',
        path    => '/usr/bin:/usr/sbin:/bin:/usr/local/bin',
        returns => [0,1],
        require => $require_list;
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

  if ($::galera_joined_exist and $::galera_status == '200') {
    galera_maxscale::create_user {
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
    if $proxysql_password {
      galera_maxscale::create_user { 'proxysql':
        galera_hosts   => $galera_hosts,
        proxysql_hosts => $proxysql_hosts,
        proxysql_vip   => $proxysql_vip,
        dbpass         => $proxysql_password;
      }
    }
  }

}
