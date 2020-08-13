# == Define: galera_proxysql::create::extra_user
#
# Add users to existing database
#
define galera_proxysql::create::extra_user (
  Variant[Sensitive, String] $dbpass,
  String $database,
  $galera_hosts                      = undef,
  $proxysql_hosts                    = {},
  $proxysql_vip                      = {},
  $privileges                        = ['SELECT'],
  #Enum[
  #  'present', 'absent',
  #  present, absent] $show_databases = absent,
  Variant[Array, String] $table      = '*.*',  # Example: 'schema.table', 'schema.*', '*.*'
  $dbuser                            = $name,  # do not drop DB if a user is removed
  Enum[
    'present', 'absent',
    present, absent] $ensure    = present,
  ) {

  if $dbpass =~ String {
    notify { "'dbpass' String detected for ${dbuser}!":
      message => 'It is advisable to use the Sensitive datatype for "dbpass"';
    }
    $dbpass_wrap = Sensitive($dbpass)
  } else {
    $dbpass_wrap = $dbpass
  }

  if ($proxysql_hosts) {
    $host_hash = deep_merge($galera_hosts, $proxysql_hosts, $proxysql_vip)
  } else {
    $host_hash = $galera_hosts
  }

  if $table =~ String {
    $schema_name = split($table, '[.]')[0]
  } else {
    $schema_name = $table.map |$item| {split($item, '[.]')[0]}
  }

  if defined(Class['::galera_proxysql::join']) {
    if ($galera_hosts) {
      $host_hash.each | $host_name, $host_ips | {
        mysql_user {
          "${dbuser}@${host_ips['ipv4']}":
            ensure        => $ensure,
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
          "${dbuser}@${host_name}":
            ensure        => $ensure,
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
        }
        galera_proxysql::create::grant {
          default:
            ensure     => $ensure,
            dbuser     => $dbuser,
            table      => $table,
            privileges => $privileges;
          "${host_ips['ipv4']} ${dbuser}":
            source  => $host_ips['ipv4'],
            require => Mysql_user["${dbuser}@${host_ips['ipv4']}"];
          "${host_name} ${dbuser}":
            source  => $host_name,
            require => Mysql_user["${dbuser}@${host_name}"];
          "${host_ips['ipv4']} ${dbuser} show_databases":
            table   => '*.*',
            source  => $host_ips['ipv4'],
            require => Mysql_user["${dbuser}@${host_ips['ipv4']}"];
          "${host_name} ${dbuser} show_databases":
            table   => '*.*',
            source  => $host_name,
            require => Mysql_user["${dbuser}@${host_name}"];
        }
        if has_key($host_ips, 'ipv6') {
          mysql_user { "${dbuser}@${host_ips['ipv6']}":
            ensure        => $ensure,
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
          }
          galera_proxysql::create::grant { "${host_ips['ipv6']} ${dbuser} show_databases":
            ensure     => $show_databases,
            dbuser     => $dbuser,
            table      => '*.*',
            privileges => $privileges,
            source     => $host_ips['ipv6'],
            require    => Mysql_user["${dbuser}@${host_ips['ipv6']}"];
          }
          galera_proxysql::create::grant { "${host_ips['ipv6']} ${dbuser}":
            ensure     => $ensure,
            source     => $host_ips['ipv6'],
            dbuser     => $dbuser,
            table      => $table,
            privileges => $privileges,
            require    => Mysql_user["${dbuser}@${host_ips['ipv6']}"]
          }
        }
      }
    } else {
      fail('hash galera_hosts not defined')
    }
  } else {
    if $ensure == present or $ensure == 'present' {
      $concat_order = fqdn_rand(999999997, "${dbuser}${dbpass_wrap.unwrap}")+2
      $concat_content = ",{
    username = \"${dbuser}\"
    password = \"${dbpass_wrap.unwrap}\"
    default_hostgroup = 0
    active = 1
  }"
      concat::fragment { "proxysql_cnf_fragment_${dbuser}_${dbpass_wrap}":
        target  => '/etc/proxysql.cnf',
        content => $concat_content,
        order   => $concat_order;
      }
    }
  }

}
