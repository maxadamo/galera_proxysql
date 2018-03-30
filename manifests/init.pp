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
# [*backup_compress*] <Bool>
#   default: false (whether to compress or not backup)
#
# [*backup_retention*] <Int>
#   default: 3 (number of day to save the backups)
#
# [*backup_dir*] <String>
#   default: '/mnt/galera' (the directory where we store the backups. You are responsible for
#            creating sufficient space, a volume, mount a network share on the mount point)
#
# [*daily_hotbackup*] <Bool>
#   WIP: not yet in use
#
# [*galera_cluster_name*] <String>
#   default: ${::environment}_${::hostgroup} (if you don't have $::hostgroup I'll throw a fail)
#
# [*galera_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to the cluster: not less than 3, not even.
#   check examples on README.md
#
# [*innodb_buffer_pool_size*] <String-number>
#   default: 0.7 => 70% of memory is assigned to this MySQL parameter
#
# [*http_proxy*] <String>
#   default: undef  http proxy used for instance by gpg key
#   Example: 'http://proxy.example.net:8080'
#
# [*innodb_buffer_pool_instances*] <String-number>
#   default: 1
#
# [*innodb_flush_method*] <String>
#   default: O_DIRECT
#
# [*innodb_io_capacity*] <Int>
#   default: 200
#
# [*innodb_log_file_size*] <String>
#   default: 512M
#
# [*logdir*] <String>
#   default: undef
#
# [*lv_size*] <String-number>
#   default: undef => number of GB. It requires that 'manage_lvm' is set to true
#
# [*manage_firewall*] <Bool>
#   default: true => Strongly recommended. It requires puppetlabs/firewall
#
# [*manage_lvm*] <Bool>
#   default: false => creates and mount a volume on /var/lib/mysql. I encourage its use.
#
# [*manage_repo*] <Bool>
#   default: true => please check repo.pp to understand what repos are neeeded
#
# [*galera_version*] <String>
#   default: latest
#
# [*max_connections*] <Int>
#   default: 1024
#
# [*proxysql_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to proxysql cluster.
#   Currently only 2 hosts are supported. Check examples on README.md
#   This parameter is needed in the Galera cluster as well, to setup The
#   users privileges in the database and the firewall rules
#
# [*proxysql_vip*] <Hash>
#   host, ipv4 (optionally ipv6) for the VIP
#
# [*proxysql_password*] <String>
#   proxysql user password
#
# [*monitor_password*] <String>
#   proxysql monitor password
#
# [*monitor_username*] <String>
#   default: monitor
#
# [*other_pkgs*] <Array>
#   list of packages needed by Percona Cluster
#
# [*root_password*]
#   MySQL root password
#
# [*sst_password*]
#   SST user password
#
# [*thread_cache_size*] <Int>
#   default: 16
#
# [*tmpdir*] <String>
#   default: undef
#
# [*trusted_networks*] <Array>
#   default: undef => List of IPv4 and/or IPv6 host and or networks.
#            It's used by iptables to determine from where to allow access to MySQL
#
# === ToDo
#
# - Add root password change
#
# === Authors
#
# 2018-Jan-15: Massimiliano Adamo <maxadamo@gmail.com>
#
class galera_proxysql (

  # galera parameters
  $backup_compress              = $::galera_proxysql::params::backup_compress,
  $backup_dir                   = $::galera_proxysql::params::backup_dir,
  $backup_retention             = $::galera_proxysql::params::backup_retention,
  $daily_hotbackup              = $::galera_proxysql::params::daily_hotbackup,
  $galera_cluster_name          = $::galera_proxysql::params::galera_cluster_name,
  $galera_hosts                 = $::galera_proxysql::params::galera_hosts,
  $innodb_buffer_pool_size      = $::galera_proxysql::params::innodb_buffer_pool_size,
  $innodb_buffer_pool_instances = $::galera_proxysql::params::innodb_buffer_pool_instances,
  $innodb_flush_method          = $::galera_proxysql::params::innodb_flush_method,
  $innodb_io_capacity           = $::galera_proxysql::params::innodb_io_capacity,
  $innodb_log_file_size         = $::galera_proxysql::params::innodb_log_file_size,
  $logdir                       = $::galera_proxysql::params::logdir,
  $lv_size                      = $::galera_proxysql::params::lv_size,
  $percona_major_version        = $::galera_proxysql::params::percona_major_version,
  $manage_lvm                   = $::galera_proxysql::params::manage_lvm,
  $max_connections              = $::galera_proxysql::params::max_connections,
  $monitor_password             = $::galera_proxysql::params::monitor_password,
  $monitor_username             = $::galera_proxysql::params::monitor_username,
  $other_pkgs                   = $::galera_proxysql::params::other_pkgs,
  $query_cache                  = $::galera_proxysql::params::query_cache,
  $root_password                = $::galera_proxysql::params::root_password,
  $slow_query_time              = $::galera_proxysql::params::slow_query_time,
  $sst_password                 = $::galera_proxysql::params::sst_password,
  $thread_cache_size            = $::galera_proxysql::params::thread_cache_size,
  $tmpdir                       = $::galera_proxysql::params::tmpdir,
  $trusted_networks             = $::galera_proxysql::params::trusted_networks,
  $vg_name                      = $::galera_proxysql::params::vg_name,

  # proxysql parameters
  $proxysql_version             = $::galera_proxysql::params::proxysql_version,
  $proxysql_vip                 = $::galera_proxysql::params::proxysql_vip,
  $proxysql_password            = $::galera_proxysql::params::proxysql_password,

  # proxysql Keepalive configuration
  $network_interface            = ::galera_proxysql::params::network_interface,

  # common parameters
  $http_proxy                   = $::galera_proxysql::params::http_proxy,
  $manage_firewall              = $::galera_proxysql::params::manage_firewall,
  $manage_repo                  = $::galera_proxysql::params::manage_repo,
  $proxysql_hosts               = $::galera_proxysql::params::proxysql_hosts,

) inherits galera_proxysql::params {

  if $::osfamily != 'RedHat' { fail("${::operatingsystem} not yet supported") }

  # checking cluster status through the facter galera_status
  if $::galera_status == '200' {
    $msg = "HTTP/1.1 ${::galera_status}: the node is healthy and belongs to the cluster ${galera_cluster_name}"
  } elsif $::galera_status == 'UNKNOWN' {
    $msg = "HTTP/1.1 ${::galera_status}: could not determine the status of the cluster. Most likely xinetd is not running yet"
  } else {
    $msg = "HTTP/1.1 ${::galera_status}: the node is disconnected from the cluster ${galera_cluster_name}"
  }
  notify { 'Cluster status': message => $msg; }

  $cluster_size = inline_template('<%= @galera_hosts.keys.count %>')
  $cluster_size_odd = inline_template('<% if @galera_hosts.keys.count.to_i.odd? -%>true<% end -%>')

  if $cluster_size+0 < 3 { fail('a cluster must have at least 3 nodes') }
  unless $cluster_size_odd { fail('the number of nodes in the cluster must be odd')}
  unless $root_password { fail('parameter "root_password" is missing') }
  unless $sst_password { fail('parameter "sst_password" is missing') }
  unless $monitor_password { fail('parameter "monitor_password" is missing') }

  if $manage_lvm and $lv_size == undef { fail('manage_lvm is true but lv_size is undef') }
  if $manage_lvm and $vg_name == undef { fail('manage_lvm is true but vg_name is undef') }
  if $manage_lvm == undef and $lv_size { fail('manage_lvm is undef but lv_size is defined') }

  $galera_first_key = inline_template('<% @galera_hosts.each_with_index do |(key, value), index| %><% if index == 0 %><%= key %><% end -%><% end -%>')
  if has_key($galera_hosts[$galera_first_key], 'ipv6') {
    $ipv6_true = true
  } else {
    $ipv6_true = undef
  }

  galera_proxysql::root_password { $root_password:; }

  class {
    '::galera_proxysql::files':
      backup_compress              => $backup_compress,
      backup_dir                   => $backup_dir,
      backup_retention             => $backup_retention,
      galera_cluster_name          => $galera_cluster_name,
      galera_hosts                 => $galera_hosts,
      innodb_buffer_pool_instances => $innodb_buffer_pool_instances,
      innodb_flush_method          => $innodb_flush_method,
      innodb_io_capacity           => $innodb_io_capacity,
      innodb_log_file_size         => $innodb_log_file_size,
      logdir                       => $logdir,
      max_connections              => $max_connections,
      monitor_password             => $monitor_password,
      monitor_username             => $monitor_username,
      query_cache                  => $query_cache,
      root_password                => $root_password,
      sst_password                 => $sst_password,
      tmpdir                       => $tmpdir,
      thread_cache_size            => $thread_cache_size,
      slow_query_time              => $slow_query_time;
    '::galera_proxysql::install':
      other_pkgs            => $other_pkgs,
      percona_major_version => $percona_major_version;
    '::galera_proxysql::join':
      percona_major_version => $percona_major_version,
      monitor_password      => $monitor_password,
      root_password         => $root_password,
      sst_password          => $sst_password,
      galera_hosts          => $galera_hosts,
      proxysql_hosts        => $proxysql_hosts,
      proxysql_vip          => $proxysql_vip,
      manage_lvm            => $manage_lvm;
    '::galera_proxysql::backup':
      galera_hosts        => $galera_hosts,
      daily_hotbackup     => $daily_hotbackup,
      galera_cluster_name => $galera_cluster_name,
      backup_dir          => $backup_dir;
    '::galera_proxysql::repo':
      http_proxy  => $http_proxy,
      manage_repo => $manage_repo;
    '::galera_proxysql::lvm':
      manage_lvm => $manage_lvm,
      vg_name    => $vg_name,
      lv_size    => $lv_size;
    '::galera_proxysql::services':;
    '::mysql::client':
      package_name => "Percona-XtraDB-Cluster-client-${percona_major_version}";
  }

  unless any2bool($manage_firewall) == false {
    class { 'galera_proxysql::firewall':
      manage_ipv6      => $ipv6_true,
      galera_hosts     => $galera_hosts,
      trusted_networks => $trusted_networks;
    }
  }

}
