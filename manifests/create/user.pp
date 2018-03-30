
# == Define: galera_proxysql::create::user
#
define galera_proxysql::create::user (
  $dbpass,
  $galera_hosts,
  $proxysql_hosts = {},
  $proxysql_vip   = {},
  $privileges     = ['SELECT', 'SHOW DATABASES'],
  $table          = '*.*',  # Example: 'schema.table', 'schema.*', '*.*'
  $dbuser         = $name
  ) {

  if ($proxysql_hosts) {
    $host_hash = deep_merge($galera_hosts, $proxysql_hosts, $proxysql_vip)
  } else {
    $host_hash = $galera_hosts
  }

  $_schema = split($table, '.')
  $schema = $_schema[0]

  notify { 'this is %{schema}':
    message => "schema is ${schema} and ${_schema}";
  }

  mysql::db { 'zabbix':
    user     => $dbuser,
    password => $dbpass,
    grant    => $privileges,
    charset  => 'utf8',
    collate  => 'utf8_bin';
  }

  $host_hash.each | $host_name, $host_ips | {
    mysql_user {
      "${dbuser}@${host_ips['ipv4']}":
        ensure        => present,
        password_hash => mysql_password($dbpass),
        provider      => 'mysql',
        require       => Mysql::Db[$schema];
      "${dbuser}@${host_name}":
        ensure        => present,
        password_hash => mysql_password($dbpass),
        provider      => 'mysql',
        require       => Mysql::Db[$schema];
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
  }

}
