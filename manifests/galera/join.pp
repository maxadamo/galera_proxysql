# == Class: galera_proxysql::galera::join
#
# This Class run exec resources to try to join, or bootstrap the cluster
#
#
class galera_proxysql::galera::join (
  $cluster_pkg_name,
  Sensitive $monitor_password,
  Sensitive $root_password,
  Sensitive $sst_password,
  $galera_hosts,
  $proxysql_hosts,
  $proxysql_vip,
  $manage_lvm,
  $manage_firewall,
  $force_ipv6,
  $pip_pkgs = $galera_proxysql::params::pip_pkgs
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
    Package[$pip_pkgs + $cluster_pkg_name]
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

  # galera never ran here: we try to bootstrap or join as new
  if $facts['galera_never_ran'] {
    unless defined(Exec['bootstrap_or_join']) {
      exec { 'bootstrap_or_join':
        command => '/usr/bin/galera_wizard.py -bn -f || /usr/bin/galera_wizard.py -jn -f',
        creates => $joined_file,
        returns => [0,1],
        require => $require,
        before  => Class['galera_proxysql::galera::sys_users_internal_wrapper'];
      }
    }
  }

  # galera has run already: we try to bootstrap or join as existing
  if (!$facts['galera_never_ran'] and $facts['galera_status'] != '200') {
    unless defined(Exec['bootstrap_or_join']) {
      exec { 'bootstrap_existing_or_join_existing':
        command => '/usr/bin/galera_wizard.py -be -f || /usr/bin/galera_wizard.py -je -f',
        creates => $joined_file,
        returns => [0,1],
        require => $require,
        before  => Class['galera_proxysql::galera::sys_users_internal_wrapper'];
      }
    }
  }

  class { 'galera_proxysql::galera::sys_users_internal_wrapper':
    galera_hosts     => $galera_hosts,
    proxysql_hosts   => $proxysql_hosts,
    proxysql_vip     => $proxysql_vip,
    sst_password     => $sst_password,
    root_password    => $root_password,
    monitor_password => $monitor_password,
    force_ipv6       => $force_ipv6;
  }

}
