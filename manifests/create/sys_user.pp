# == Define: galera_proxysql::create::sys_user
#
define galera_proxysql::create::sys_user (
  $dbpass,
  $galera_hosts,
  $proxysql_hosts = {},
  $proxysql_vip   = {},
  $dbuser         = $name
) {

  assert_private("this define should be called only by ${module_name}")

  if $dbuser == 'monitor' {
    if ($proxysql_hosts) {
      $host_hash = deep_merge($galera_hosts, $proxysql_hosts, $proxysql_vip)
    } else {
      $host_hash = $galera_hosts
    }
    $privileges = ['SELECT', 'SHOW DATABASES', 'REPLICATION CLIENT']
    $table = '*.*'
  } elsif $dbuser == 'sstuser' {
    $host_hash = $galera_hosts
    $privileges = ['PROCESS', 'SELECT', 'RELOAD', 'LOCK TABLES', 'REPLICATION CLIENT']
    $table = '*.*'
  } elsif $dbuser == 'monitor' {
    $host_hash = $galera_hosts
    $privileges = ['UPDATE']
    $table = 'test.monitor'
  }

  $host_hash.each | $host_name, $host_ips | {
    mysql_user {
      "${dbuser}@${host_ips['ipv4']}":
        ensure        => present,
        password_hash => mysql_password($dbpass.unwrap),
        provider      => 'mysql';
      "${dbuser}@${host_name}":
        ensure        => present,
        password_hash => mysql_password($dbpass.unwrap),
        provider      => 'mysql';
    }
    mysql_grant {
      "${dbuser}@${host_ips['ipv4']}/${table}":
        ensure     => present,
        user       => "${dbuser}@${host_ips['ipv4']}",
        table      => $table,
        privileges => $privileges,
        require    => Mysql_user["${dbuser}@${host_ips['ipv4']}"];
      "${dbuser}@${host_name}/${table}":
        ensure     => present,
        user       => "${dbuser}@${host_name}",
        table      => $table,
        privileges => $privileges,
        require    => Mysql_user["${dbuser}@${host_name}"];
    }
    if has_key($host_ips, 'ipv6') {
      mysql_user { "${dbuser}@${host_ips['ipv6']}":
        ensure        => present,
        password_hash => mysql_password($dbpass.unwrap),
        provider      => 'mysql';
      }
      mysql_grant { "${dbuser}@${host_ips['ipv6']}/${table}":
        ensure     => present,
        user       => "${dbuser}@${host_ips['ipv6']}",
        table      => $table,
        privileges => $privileges,
        require    => Mysql_user["${dbuser}@${host_ips['ipv6']}"];
      }
    }
  }

}
