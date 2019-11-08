# == Define: galera_proxysql::create::user
#
define galera_proxysql::create::user (
  Variant[Sensitive, String] $dbpass,
  $galera_hosts                 = undef,
  $proxysql_hosts               = {},
  $proxysql_vip                 = {},
  $privileges                   = ['SELECT', 'SHOW DATABASES'],
  Variant[Array, String] $table = '*.*',  # Example: 'schema.table', 'schema.*', '*.*'
  $dbuser                       = $name,
  $force_schema_removal         = false,  # do not drop DB if a user is removed
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

  if ($force_schema_removal) {
    $ensure_schema = absent
  } else {
    $ensure_schema = present
  }

  if defined(Class['::galera_proxysql::join']) {
    if ($galera_hosts) {
      if $schema_name =~ String {
        unless defined(Mysql::Db[$schema_name]) {
          mysql::db { $schema_name:
            ensure   => $ensure_schema,
            user     => $dbuser,
            password => $dbpass_wrap.unwrap,
            grant    => $privileges,
            charset  => 'utf8',
            collate  => 'utf8_bin';
          }
        }
      } else {
        $schema_name.each | $myschema | {
          unless defined(Mysql::Db[$myschema]) {
            mysql::db { $myschema:
              ensure   => $ensure_schema,
              user     => $dbuser,
              password => $dbpass_wrap.unwrap,
              grant    => $privileges,
              charset  => 'utf8',
              collate  => 'utf8_bin';
            }
          }
        }
      }
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
        galera_proxysql::create::grant { "${host_ips['ipv4']} ${dbuser}":
          ensure     => $ensure,
          source     => $host_ips['ipv4'],
          dbuser     => $dbuser,
          table      => $table,
          privileges => $privileges,
          require    => Mysql_user["${dbuser}@${host_ips['ipv4']}"];
        }
        galera_proxysql::create::grant { "${host_name} ${dbuser}":
          ensure     => $ensure,
          source     => $host_name,
          dbuser     => $dbuser,
          table      => $table,
          privileges => $privileges,
          require    => Mysql_user["${dbuser}@${host_name}"];
        }
        if has_key($host_ips, 'ipv6') {
          mysql_user { "${dbuser}@${host_ips['ipv6']}":
            ensure        => $ensure,
            password_hash => mysql_password($dbpass_wrap.unwrap),
            provider      => 'mysql',
            require       => Mysql::Db[$schema_name];
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
