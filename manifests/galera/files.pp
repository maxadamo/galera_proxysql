# == Class: galera_proxysql::galera::files
#
# This Class provides files
#
#
class galera_proxysql::galera::files (
  $percona_major_version,
  $cluster_pkg_name,
  $custom_server_cnf_parameters,
  $custom_client_cnf_parameters,
  $force_ipv6,
  $gcache_size,
  $custom_wsrep_options,
  $innodb_buffer_pool_size,
  $galera_cluster_name,
  $galera_hosts,
  $innodb_buffer_pool_instances,
  $innodb_flush_method,
  $innodb_io_capacity,
  $innodb_log_file_size,
  $logdir,
  $max_connections,
  $query_cache_size,
  $query_cache_type,
  Sensitive $monitor_password,
  Sensitive $root_password,
  Sensitive $sst_password,
  $thread_cache_size,
  $tmpdir
) {

  assert_private("this class should be called only by ${module_name}")

  $galera_keys = keys($galera_hosts)
  if ($force_ipv6) {
    $myip = $galera_hosts[$facts['fqdn']]['ipv6']
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv6'] }
  } else {
    $myip = $galera_hosts[$facts['fqdn']]['ipv4']
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv4'] }
  }

  $galera_joined_list = join($transformed_data, "\",\n    \"")
  if ($force_ipv6) {
    $_gcomm_list = join($transformed_data, '],[')
    $gcomm_list = "[${_gcomm_list}]"
  } else {
    $gcomm_list = join($transformed_data, ',')
  }

  unless defined( File['/root/bin'] ) {
    file { '/root/bin':
      ensure => directory,
      mode   => '0755';
    }
  }

  file {
    default:
      ensure  => file,
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      require => [
        File['/root/bin'],
        Package[$cluster_pkg_name]
      ];
    '/etc/my.cnf':
      source => "puppet:///modules/${module_name}/my.cnf";
    '/etc/my.cnf.d':
      ensure  => directory,
      purge   => true,
      recurse => true,
      force   => true;
    '/etc/logrotate.d/mysql':
      mode   => '0644',
      source => "puppet:///modules/${module_name}/logrotate_mysql";
    '/usr/bin/galera_wizard.py':
      mode   => '0755',
      source => "puppet:///modules/${module_name}/galera_wizard.py";
    '/root/galera_params.py':
      ensure => absent;
    '/root/galera_params.ini':
      mode    => '0660',
      content => Sensitive(epp("${module_name}/galera_params.ini.epp", {
        'myip'                  => $myip,
        'galera_joined_list'    => $galera_joined_list,
        'force_ipv6'            => $force_ipv6,
        'root_password'         => Sensitive($root_password),
        'sst_password'          => Sensitive($sst_password),
        'monitor_password'      => Sensitive($monitor_password),
        'percona_major_version' => $percona_major_version
      })),
      notify  => Xinetd::Service['galerachk'];
    '/etc/xinetd.d/mysqlchk':
      ensure => absent,
      notify => Xinetd::Service['galerachk'];
    '/root/.my.cnf':
      mode    => '0660',
      notify  => Xinetd::Service['galerachk'],
      content => Sensitive("[client]\nuser=root\npassword=${root_password.unwrap}\n");
    '/etc/sysconfig/clustercheck':
      notify  => Xinetd::Service['galerachk'],
      content => epp("${module_name}/clustercheck.epp");
    '/etc/my.cnf.d/client.cnf':
      source  => "puppet:///modules/${module_name}/client.cnf";
    '/etc/my.cnf.d/mysql-clients.cnf':
      content => epp("${module_name}/mysql-clients.cnf.epp");
    '/etc/my.cnf.d/server.cnf':
      content => epp("${module_name}/server.cnf.epp");
    '/etc/my.cnf.d/wsrep.cnf':
      mode    => '0640',
      content => Sensitive(epp("${module_name}/wsrep.cnf.epp", {
        'sst_password'        => Sensitive($sst_password),
        'force_ipv6'          => $force_ipv6,
        'gcomm_list'          => $gcomm_list,
        'galera_cluster_name' => $galera_cluster_name
      }));
    '/etc/my.cnf.d/mysqld_safe.cnf':
      source => "puppet:///modules/${module_name}/mysqld_safe.cnf";
  }

  file_line {
    default:
      ensure             => present,
      append_on_no_match => false,
      require            => Package[$cluster_pkg_name,];
    'mysql_systemd':
      path  => '/usr/bin/mysql-systemd',
      line  => '    /usr/sbin/mysqld --initialize-insecure --datadir="$datadir" --user=mysql',
      match => '/usr/sbin/mysqld --initialize --datadir';
    'clustercheck_one':
      path   => '/usr/bin/clustercheck',
      line   => "source /etc/sysconfig/clustercheck\n#MYSQL_USERNAME=\"\${1-clustercheckuser}\"",
      match  => '^MYSQL_USERNAME=',
      notify => Xinetd::Service['galerachk'];
    'clustercheck_two':
      path   => '/usr/bin/clustercheck',
      line   => "#MYSQL_PASSWORD=\"\${2-clustercheckpassword!}\"",
      match  => '^MYSQL_PASSWORD=',
      notify => Xinetd::Service['galerachk'];
  }

}
