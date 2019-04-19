# == Define: galera_proxysql::create::user
#
define galera_proxysql::create::user (
  Variant[Sensitive, String] $dbpass,
  $galera_hosts   = undef,
  $proxysql_hosts = {},
  $proxysql_vip   = {},
  $privileges     = ['SELECT', 'SHOW DATABASES'],
  $table          = '*.*',  # Example: 'schema.table', 'schema.*', '*.*'
  $dbuser         = $name
  ) {

  if $dbpass =~ String {
    notify { "'dbpass' String detected for ${dbuser}!":
      message => 'It is advisable to use the Sensitive type for "dbpass"';
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
  $schema_name = split($table, '[.]')[0]

  if defined(Class['::galera_proxysql::join']) {
    if ($galera_hosts) {
      mysql::db { $schema_name:
        user     => $dbuser,
        password => $dbpass_wrap.unwrap,
        grant    => $privileges,
        charset  => 'utf8',
        collate  => 'utf8_bin';
      }
      $host_hash.each | $host_name, $host_ips | {
        mysql_user {
          "${dbuser}@${host_ips['ipv4']}":
            ensure        => present,
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
          "${dbuser}@${host_name}":
            ensure        => present,
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
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
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
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
    } else {
      fail('hash galera_hosts not defined')
    }
  } else {
    $concat_order = fqdn_rand(999999997, "${dbuser}${dbpass_wrap.unwrap}")+2
    concat::fragment { "proxysql_cnf_fragment_${dbuser}_${dbpass_wrap}":
      target  => '/etc/proxysql.cnf',
      content => ",{\n    username = \"${dbuser}\"\n    password = \"${dbpass_wrap.unwrap}\"\n    default_hostgroup = 0\n    active = 1\n  }",
      order   => $concat_order;
    }
  }

}
