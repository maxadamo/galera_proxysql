# == Define: galera_proxysql::create::grant
#
define galera_proxysql::create::grant (
  Variant[Array, String] $table,
  $privileges,
  $dbuser,
  $source = $name
  ) {

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
    mysql_grant { "${dbuser}@${host_ips['ipv6']}/${table}":
      ensure     => present,
      user       => "${dbuser}@${host_ips['ipv6']}",
      table      => $table,
      privileges => $privileges,
      require    => Mysql_user["${dbuser}@${host_ips['ipv6']}"];
    }
  }

}
