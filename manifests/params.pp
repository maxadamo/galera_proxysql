# == Class: galera_proxysql::params
#
# Galera ProxySQL Parameters
#
class galera_proxysql::params {

  # print debug messages
  $puppet_debug = false

  #network parameters
  $force_ipv6 = false

  # galera parameters
  $encrypt_cluster_traffic = false # Percona 80
  $custom_server_cnf_parameters = undef
  $custom_client_cnf_parameters = undef
  $galera_cluster_name = "${::environment}_galera"
  $galera_hosts = undef
  $gcache_size = '0.15'
  $custom_wsrep_options = ''
  $innodb_buffer_pool_size = '0.7'
  $innodb_buffer_pool_instances = floor(Float.new($facts['memorysize_mb']) * Float.new(0.7)/130)
  $innodb_flush_method = 'O_DIRECT'
  $innodb_io_capacity = 200
  $innodb_log_file_size = '512M'
  $logdir = undef
  $lv_size = undef
  $percona_major_version = undef
  $percona_minor_version = 'installed'
  $manage_lvm = false
  $max_connections = 1024
  $monitor_password = undef
  $other_pkgs = [
    'percona-toolkit', 'python36-paramiko', 'python36-pip',
    'python3-devel', 'python36-rpm', 'qpress', 'nc', 'socat'
  ]
  $pip_pkgs = ['distro', 'multiping', 'ping3', 'pysystemd', 'mysql']
  $query_cache_size = 0
  $query_cache_type = 0
  $root_password = undef
  $sst_password = undef
  $thread_cache_size = 16
  $tmpdir = undef
  $trusted_networks = undef
  $vg_name = undef
  $joined_exists = find_file('/var/lib/mysql/gvwstate.dat')
  $rootcnf_exist = find_file('/root/.my.cnf')
  $it_ran_already = find_file('/var/lib/mysql/grastate.dat')

  # proxysql configuration
  $proxysql_package = 'proxysql2'
  $proxysql_port = 3306
  $proxysql_admin_port = 3307
  $proxysql_version  = 'latest'
  $proxysql_mysql_version = '5.7.22-22-57'
  $proxysql_vip = undef
  $proxysql_admin_password = Sensitive('admin')
  $keepalived_sysconf_options = '-D'
  $ssl_ca_source_path = undef
  $ssl_cert_source_path = undef
  $ssl_key_source_path = undef
  # proxysql Keepalive configuration
  $network_interface = 'eth0'

  # Common Parameters
  $http_proxy = absent # example: 'http://proxy.example.net:8080'
  $manage_firewall = false
  $manage_repo = true
  $manage_epel = true
  $proxysql_hosts = undef

}
