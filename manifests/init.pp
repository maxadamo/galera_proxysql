# == Class: galera
#
# Setup Galera Percona Cluster and ProxySQL
#
# == Quick Overview
#
# (see file README.md )
#
# === Parameters & Variables
#
# *puppet_debug* <Bool>
#   default: false => whether to print or not cluster status)
#
# *custom_server_cnf_parameters* <String>
#   default: undef => it can be a multiline string with custom values to add to server.cnf)
#
# *custom_client_cnf_parameters* <String>
#   default: undef => it can be a multiline string with custom values to add to mysql-client.cnf under section [mysql])
#
# *force_ipv6* <Bool>
#   default: false => whether to use IPv6 on cluster communication)
#
# *galera_cluster_name* <String>
#   default: ${::environment}_galera
#
# *galera_hosts* <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to the cluster: not less than 3, not even.
#   check examples on README.md
#
# *custom_wsrep_options* <String-number>
#   default: '' => a semi-colon separate list of values (see Galera Cluster documentation)
#
# *gcache_size* <String-number>
#   default: 0.15 => 15% of memory is assigned to this MySQL parameter
#
# *innodb_buffer_pool_size* <String-number>
#   default: 0.7 => 70% of memory is assigned to this MySQL parameter
#
# *http_proxy* <String>
#   default: undef => http proxy used for instance by gpg key
#   Example: 'http://proxy.example.net:8080'
#
# *innodb_buffer_pool_instances* <String-number>
#   default: 1
#
# *innodb_flush_method* <String>
#   default: O_DIRECT
#
# *innodb_io_capacity* <Int>
#   default: 200
#
# *innodb_log_file_size* <String>
#   default: 512M
#
# *logdir* <String>
#   default: undef
#
# *lv_size* <String-number>
#   default: undef => number of GB. It requires that 'manage_lvm' is set to true
#
# *manage_firewall* <Bool>
#   default: false => It requires puppetlabs/firewall
#
# *manage_lvm* <Bool>
#   default: false => creates and mount a volume on /var/lib/mysql. I encourage its use.
#
# *manage_repo* <Bool>
#   default: true => please check repo.pp to understand what repos are neeeded
#
# *manage_epel* <Bool>
#   default: true => whether to handle EPEL within this module
#
# *galera_version* <String>
#   default: latest
#
# *max_connections* <Int>
#   default: 1024
#
# *proxysql_hosts* <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to proxysql cluster.
#   Currently only 2 hosts are supported. Check examples on README.md
#   This parameter is needed in the Galera cluster as well, to setup The
#   users privileges in the database and the firewall rules
#
# *proxysql_vip* <Hash>
#   host, ipv4 (optionally ipv6) for the VIP
#
# *proxysql_admin_password* <Sensitive>
#   proxysql user password
#
# *monitor_password* <Sensitive>
#   galera and proxysql monitor password
#
# *other_pkgs* <Array>
#   list of packages needed by Percona Cluster
#
# *root_password* <Sensitive>
#   MySQL root password
#
# *sst_password* <Optional[Sensitive]>
#   SST user password
#
# *thread_cache_size* <Int>
#   default: 16
#
# *tmpdir* <String>
#   default: undef
#
# *trusted_networks* <Array>
#   default: undef => List of IPv4 and/or IPv6 host and or networks.
#            It's used by iptables to determine from where to allow access to MySQL
#
# *encrypt_cluster_traffic* <Boolean>
#   default: undef => If you set it to true, you need to supply your certificates and 
#            server configuration parameters, using `custom_server_cnf_parameters`
#
# === ToDo
#
# - enables SSL in the backend
#
# === Authors
#
# 2018-Jan-15: Massimiliano Adamo <maxadamo@gmail.com>
#
#
class galera_proxysql (

  # print debug messages
  Boolean $puppet_debug = $galera_proxysql::params::puppet_debug,

  # galera parameters
  Enum['56', '57', '80'] $percona_major_version = $galera_proxysql::params::percona_major_version,
  Boolean $encrypt_cluster_traffic                    = $galera_proxysql::params::encrypt_cluster_traffic,  # Percona 80 only
  $manage_lvm                                         = $galera_proxysql::params::manage_lvm,
  $vg_name                                            = $galera_proxysql::params::vg_name,
  $lv_size                                            = $galera_proxysql::params::lv_size,
  Variant[Hash, String] $custom_server_cnf_parameters = $galera_proxysql::params::custom_server_cnf_parameters,
  Variant[Hash, String] $custom_client_cnf_parameters = $galera_proxysql::params::custom_client_cnf_parameters,
  $custom_wsrep_options                               = $galera_proxysql::params::custom_wsrep_options,
  Boolean $force_ipv6                                 = $galera_proxysql::params::force_ipv6,
  $galera_cluster_name                                = $galera_proxysql::params::galera_cluster_name,
  $galera_hosts                                       = $galera_proxysql::params::galera_hosts,
  $gcache_size                                        = $galera_proxysql::params::gcache_size,
  $innodb_buffer_pool_size                            = $galera_proxysql::params::innodb_buffer_pool_size,
  $innodb_buffer_pool_instances                       = $galera_proxysql::params::innodb_buffer_pool_instances,
  $innodb_flush_method                                = $galera_proxysql::params::innodb_flush_method,
  $innodb_io_capacity                                 = $galera_proxysql::params::innodb_io_capacity,
  $innodb_log_file_size                               = $galera_proxysql::params::innodb_log_file_size,
  $logdir                                             = $galera_proxysql::params::logdir,
  $percona_minor_version                              = $galera_proxysql::params::percona_minor_version,
  $max_connections                                    = $galera_proxysql::params::max_connections,
  $other_pkgs                                         = $galera_proxysql::params::other_pkgs,
  $query_cache_size                                   = $galera_proxysql::params::query_cache_size,
  $query_cache_type                                   = $galera_proxysql::params::query_cache_type,
  $thread_cache_size                                  = $galera_proxysql::params::thread_cache_size,
  $tmpdir                                             = $galera_proxysql::params::tmpdir,
  $trusted_networks                                   = $galera_proxysql::params::trusted_networks,
  Sensitive $monitor_password                         = $galera_proxysql::params::monitor_password,
  Optional[Sensitive] $sst_password                   = $galera_proxysql::params::sst_password,
  Sensitive $root_password                            = $galera_proxysql::params::root_password,

  # proxysql parameters
  $proxysql_version                     = $galera_proxysql::params::proxysql_version,
  Optional[Stdlib::Port] $proxysql_port = undef,
  Hash $proxysql_vip                    = $galera_proxysql::params::proxysql_vip,
  Sensitive $proxysql_admin_password    = $galera_proxysql::params::proxysql_admin_password,

  # proxysql Keepalive configuration
  $network_interface = $galera_proxysql::params::network_interface,

  # common parameters
  $http_proxy              = $galera_proxysql::params::http_proxy,
  Boolean $manage_firewall = $galera_proxysql::params::manage_firewall,
  Boolean $manage_repo     = $galera_proxysql::params::manage_repo,
  Boolean $manage_epel     = $galera_proxysql::params::manage_epel,
  Hash $proxysql_hosts     = $galera_proxysql::params::proxysql_hosts,

) inherits galera_proxysql::params {

  if $facts['osfamily'] != 'RedHat' { fail("${facts['operatingsystem']} not yet supported") }

  if $puppet_debug {
    # checking cluster status through the facter galera_status
    if $facts['galera_status'] == '200' {
      $msg = "HTTP/1.1 ${facts['galera_status']}: the node is healthy and belongs to the cluster ${galera_cluster_name}"
    } elsif $facts['galera_status'] == 'UNKNOWN' {
      $msg = "HTTP/1.1 ${facts['galera_status']}: could not determine the status of the cluster. Most likely xinetd is not running yet"
    } else {
      $msg = "HTTP/1.1 ${facts['galera_status']}: the node is disconnected from the cluster ${galera_cluster_name}"
    }
    notify { 'Cluster status': message => $msg; }
  }

  if $percona_major_version in ['56', '57'] {
    if $encrypt_cluster_traffic {
      fail('Please do not use $encrypt_cluster_traffic with Percona 56 and 57')
    }
    if !$sst_password {
      fail('$sst password is mandatory with Percona 56 and 57')
    }
  } elsif $percona_major_version == '80' {
    if $sst_password {
      fail('$sst password is supported only with Percona 56 and 57')
    }
    if $encrypt_cluster_traffic and $custom_server_cnf_parameters == {} {
      # It requires further investigation
      fail('If you want to encrypt your traffic you need to supply the necessary parameters through $custom_server_cnf_parameters')
    }
    unless $facts['galera_gcc_exist']  {
      fail('please install gcc (it is required to install mysql PIP package for Percona 80)')
    }
  }

  $cluster_size = length(keys($galera_hosts))
  $cluster_size_odd = (($cluster_size % 2) == 1)

  if $cluster_size == 1 { fail('I cowardly refuse to create one cluster only with one node') }
  unless $cluster_size_odd { fail('the number of nodes in the cluster must be odd') }

  if $manage_lvm and $lv_size == undef { fail('manage_lvm is true but lv_size is undef') }
  if $manage_lvm and $vg_name == undef { fail('manage_lvm is true but vg_name is undef') }
  if $manage_lvm == undef and $lv_size { fail('manage_lvm is undef but lv_size is defined') }

  $galera_first_key = keys($galera_hosts)[0]
  if has_key($galera_hosts[$galera_first_key], 'ipv6') {
    $ipv6_true = true
  } else {
    $ipv6_true = undef
  }

  case $percona_major_version {
    '80': {
      $cluster_pkg_name = 'percona-xtradb-cluster-full'
      $client_pkg_name = 'percona-xtradb-cluster-client'
      $devel_pkg_name = 'percona-xtradb-cluster-devel'
    }
    default: {
      $cluster_pkg_name = "Percona-XtraDB-Cluster-full-${percona_major_version}"
      $client_pkg_name = "Percona-XtraDB-Cluster-client-${percona_major_version}"
      $devel_pkg_name = "Percona-XtraDB-Cluster-devel-${percona_major_version}"
    }
  }

  class {
    'galera_proxysql::galera::files':
      percona_major_version        => $percona_major_version,
      cluster_pkg_name             => $cluster_pkg_name,
      custom_server_cnf_parameters => $custom_server_cnf_parameters,
      custom_client_cnf_parameters => $custom_client_cnf_parameters,
      force_ipv6                   => $force_ipv6,
      gcache_size                  => $gcache_size,
      custom_wsrep_options         => $custom_wsrep_options,
      innodb_buffer_pool_size      => $innodb_buffer_pool_size,
      galera_cluster_name          => $galera_cluster_name,
      galera_hosts                 => $galera_hosts,
      innodb_buffer_pool_instances => $innodb_buffer_pool_instances,
      innodb_flush_method          => $innodb_flush_method,
      innodb_io_capacity           => $innodb_io_capacity,
      innodb_log_file_size         => $innodb_log_file_size,
      logdir                       => $logdir,
      max_connections              => $max_connections,
      query_cache_size             => $query_cache_size,
      query_cache_type             => $query_cache_type,
      monitor_password             => Sensitive($monitor_password),
      root_password                => Sensitive($root_password),
      sst_password                 => $sst_password,
      thread_cache_size            => $thread_cache_size,
      tmpdir                       => $tmpdir;
    'galera_proxysql::galera::install':
      manage_epel           => $manage_epel,
      cluster_pkg_name      => $cluster_pkg_name,
      devel_pkg_name        => $devel_pkg_name,
      percona_major_version => $percona_major_version,
      percona_minor_version => $percona_minor_version;
    'galera_proxysql::galera::join':
      percona_major_version => $percona_major_version,
      manage_firewall       => $manage_firewall,
      cluster_pkg_name      => $cluster_pkg_name,
      monitor_password      => Sensitive($monitor_password),
      root_password         => Sensitive($root_password),
      sst_password          => $sst_password,
      galera_hosts          => $galera_hosts,
      proxysql_hosts        => $proxysql_hosts,
      proxysql_vip          => $proxysql_vip,
      manage_lvm            => $manage_lvm,
      force_ipv6            => $force_ipv6;
    'galera_proxysql::galera::repo':
      percona_major_version => $percona_major_version,
      http_proxy            => $http_proxy,
      manage_repo           => $manage_repo,
      manage_epel           => $manage_epel;
    'galera_proxysql::galera::lvm':
      manage_lvm       => $manage_lvm,
      vg_name          => $vg_name,
      lv_size          => $lv_size,
      cluster_pkg_name => $cluster_pkg_name;
    'galera_proxysql::galera::services':;
    'mysql::client':
      package_name => $client_pkg_name;
  }

  if $manage_firewall {
    class { 'galera_proxysql::firewall':
      use_ipv6         => $ipv6_true,
      proxysql_port    => $proxysql_port,
      galera_hosts     => $galera_hosts,
      proxysql_hosts   => $proxysql_hosts,
      proxysql_vip     => $proxysql_vip,
      trusted_networks => $trusted_networks;
    }
  }

}
