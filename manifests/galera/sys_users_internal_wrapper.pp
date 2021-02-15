# == Class: galera_proxysql::galera::sys_users_internal_wrapper
#
# This Class manages system users
#
#
class galera_proxysql::galera::sys_users_internal_wrapper (
  Sensitive $root_password,
  Sensitive $monitor_password,
  Sensitive $sst_password,
  $galera_hosts,
  $proxysql_hosts,
  $proxysql_vip,
  $force_ipv6
) {

  assert_private("this class should be called only by ${module_name}")

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
    galera_proxysql::create::root_password { 'root':
      force_ipv6 => $force_ipv6,
      root_pass  => Sensitive($root_password);
    }
  }

}
