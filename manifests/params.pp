# == Class: galera_proxysql::params
#
# Galera Parameters
#
class galera_proxysql::params {

  # print debug messages
  $puppet_debug = undef

  # backup parameters (this funcionality is not yet properly implemented)
  $backup_compress = false
  $backup_retention = 3
  $backup_dir = '/mnt/galera'
  $daily_hotbackup = undef

  #network parameters
  $force_ipv6 = false

  # galera parameters
  $custom_server_cnf_parameters = undef
  $galera_cluster_name = "${::environment}_galera"
  $galera_hosts = undef
  $innodb_buffer_pool_size = '0.7'
  $innodb_buffer_pool_instances = 1
  $innodb_flush_method = 'O_DIRECT'
  $innodb_io_capacity = 200
  $innodb_log_file_size = '512M'
  $logdir = undef
  $lv_size = undef
  $percona_major_version = '57'
  $percona_minor_version = 'installed'
  $manage_lvm = undef
  $max_connections = 1024
  $monitor_password = undef
  $other_pkgs = [
    'percona-xtrabackup-24', 'percona-toolkit', 'python-paramiko',
    'MySQL-python', 'qpress', 'nc', 'socat'
  ]
  $query_cache_size = 0
  $query_cache_type = 0
  $root_password = undef
  $sst_password = undef
  $thread_cache_size = 16
  $tmpdir = undef
  $trusted_networks = undef
  $vg_name = undef

  # proxysql configuration
  $proxysql_version  = 'latest'
  $proxysql_mysql_version = '5.7.22-22-57'
  $proxysql_vip = undef
  $proxysql_admin_password = 'admin'
  $proxysql_users = {}

  # proxysql Keepalive configuration
  $network_interface = 'eth0'
  $limitnofile = undef  # limit file numbder. Example: 65535

  # Common Parameters
  $http_proxy = absent # example: 'http://proxy.example.net:8080'
  $manage_firewall = true
  $manage_repo = true
  $proxysql_hosts = undef

}
