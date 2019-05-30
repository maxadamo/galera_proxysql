# == Class: galera_proxysql::files
#
# This Class provides files
#
class galera_proxysql::files (
  $percona_major_version        = $galera_proxysql::params::percona_major_version,
  $custom_server_cnf_parameters = $galera_proxysql::params::custom_server_cnf_parameters,
  $custom_client_cnf_parameters = $galera_proxysql::params::custom_client_cnf_parameters,
  $force_ipv6                   = $galera_proxysql::params::force_ipv6,
  $galera_cluster_name          = $galera_proxysql::params::galera_cluster_name,
  $galera_hosts                 = $galera_proxysql::params::galera_hosts,
  $innodb_buffer_pool_instances = $galera_proxysql::params::innodb_buffer_pool_instances,
  $innodb_flush_method          = $galera_proxysql::params::innodb_flush_method,
  $innodb_io_capacity           = $galera_proxysql::params::innodb_io_capacity,
  $innodb_log_file_size         = $galera_proxysql::params::innodb_log_file_size,
  $logdir                       = $galera_proxysql::params::logdir,
  $max_connections              = $galera_proxysql::params::max_connections,
  Sensitive $monitor_password   = $galera_proxysql::params::monitor_password,
  $query_cache_size             = $galera_proxysql::params::query_cache_size,
  $query_cache_type             = $galera_proxysql::params::query_cache_type,
  Sensitive $root_password      = $galera_proxysql::params::root_password,
  Sensitive $sst_password       = $galera_proxysql::params::sst_password,
  $thread_cache_size            = $galera_proxysql::params::thread_cache_size,
  $tmpdir                       = $galera_proxysql::params::tmpdir,
) inherits galera_proxysql::params {

  $galera_keys = keys($galera_hosts)
  if ($force_ipv6) {
    $myip = $galera_hosts[$::fqdn]['ipv6']
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv6'] }
  } else {
    $myip = $galera_hosts[$::fqdn]['ipv4']
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
        FIle['/root/bin'],
        Package["Percona-XtraDB-Cluster-full-${percona_major_version}"]
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
      require            => Package["Percona-XtraDB-Cluster-full-${percona_major_version}"];
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
