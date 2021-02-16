# == Class: galera_proxysql::galera::sys_users_internal_wrapper
#
# This Class manages system users
#
#
class galera_proxysql::galera::sys_users_internal_wrapper (
  Sensitive $root_password,
  Sensitive $monitor_password,
  Optional[Sensitive] $sst_password,
  $galera_hosts,
  $proxysql_hosts,
  $proxysql_vip,
  $force_ipv6,
  $percona_major_version,
  $joined_exists = $galera_proxysql::params::joined_exists,
) {

  assert_private("this class should be called only by ${module_name}")

  if ($joined_exists and $facts['galera_status'] == '200') {

    if $percona_major_version in ['56', '57'] {
      galera_proxysql::create::sys_user { 'sstuser':
        galera_hosts   => $galera_hosts,
        proxysql_hosts => $proxysql_hosts,
        proxysql_vip   => $proxysql_vip,
        dbpass         => $sst_password;
      }
    }

    galera_proxysql::create::sys_user { 'monitor':
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
