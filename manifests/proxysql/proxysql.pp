# == Class: galera_maxscale::proxysql::proxysql
#
# === Parameters & Variables
#
# [*galera_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to the cluster: not less than 3, not even.
#   check examples on README.md
#
# [*proxysql_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to ProxySQL cluster.
#   Currently only 2 hosts are supported. Check examples on README.md
#
# [*proxysql_vip*] <Hash>
#   host, ipv4 (optionally ipv6) for the VIP
#
# [*proxysql_password*] <String>
#   proxysql user password
#
# [*trusted_networks*] <Array>
#   default: undef => List of IPv4 and/or IPv6 host and or networks.
#            It's used by iptables to determine from where to allow access to MySQL
#
# [*manage_repo*] <Bool>
#   default: true => please check repo.pp to understand what repos are neeeded
#
# [*http_proxy*] <String>
#   default: undef  http proxy used for instance by gpg key
#   Example: 'http://proxy.example.net:8080'
#
#
class galera_maxscale::proxysql::proxysql (
  $percona_major_version  = $::galera_maxscale::params::percona_major_version,
  $galera_hosts           = $::galera_maxscale::params::galera_hosts,
  $manage_repo            = $::galera_maxscale::params::manage_repo,
  $proxysql_hosts         = $::galera_maxscale::params::proxysql_hosts,
  $proxysql_vip           = $::galera_maxscale::params::proxysql_vip,
  $proxysql_password      = $::galera_maxscale::params::proxysql_password,
  $trusted_networks       = $::galera_maxscale::params::trusted_networks,
  $http_proxy             = $::galera_maxscale::params::http_proxy,
  $network_interface      = $::galera_maxscale::params::network_interface,
  $proxysql_version       = $::galera_maxscale::params::proxysql_version
  ) inherits galera_maxscale::params {

  $proxysql_key_first = inline_template('<% @proxysql_hosts.each_with_index do |(key, value), index| %><% if index == 0 %><%= key %><% end -%><% end -%>')
  $vip_key = inline_template('<% @proxysql_vip.each do |key, value| %><%= key %><% end -%>')
  $vip_ip = $proxysql_vip[$vip_key]['ipv4']
  if has_key($proxysql_hosts[$proxysql_key_first], 'ipv6') {
    $ipv6_true = true
  } else {
    $ipv6_true = undef
  }

  class {
    '::galera_maxscale::repo':
      http_proxy  => $http_proxy,
      manage_repo => $manage_repo;
    '::galera_maxscale::proxysql::keepalived':
      manage_ipv6       => $ipv6_true,
      proxysql_hosts    => $proxysql_hosts,
      network_interface => $network_interface,
      proxysql_vip      => $proxysql_vip;
    '::galera_maxscale::firewall':
      manage_ipv6      => $ipv6_true,
      galera_hosts     => $galera_hosts,
      proxysql_hosts   => $proxysql_hosts,
      proxysql_vip     => $proxysql_vip,
      trusted_networks => $trusted_networks;
  }

  service { 'proxysql':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'redhat',
    require    => Package['proxysql'];
  }

  unless any2bool($manage_repo) == false {
    package {
      default:
        require => Yumrepo['Percona'];
      "Percona-Server-shared-compat-${percona_major_version}":
        ensure => installed,
        before => Package["Percona-Server-client-${percona_major_version}"];
      "Percona-Server-client-${percona_major_version}":
        ensure => installed,
        before => Package['proxysql'];
      'proxysql':
        ensure  => $proxysql_version;
    }
  } else {
    package {
      "Percona-Server-shared-compat-${percona_major_version}":
        ensure => installed,
        before => Package["Percona-Server-client-${percona_major_version}"];
      "Percona-Server-client-${percona_major_version}":
        ensure => installed,
        before => Package['proxysql'];
      'proxysql':
        ensure  => $proxysql_version;
    }
  }

  file {
    default:
      mode    => '0755',
      owner   => proxysql,
      group   => proxysql,
      require => Package['proxysql'],
      notify  => Service['proxysql'];
    '/etc/proxysql.cnf':
      ensure  => file,
      mode    => '0640',
      before  => File['/etc/init.d/proxysql'],
      content => template("${module_name}/proxysql.cnf.erb");
    '/etc/init.d/proxysql':
      ensure => file,
      source => "puppet:///modules/${module_name}/proxysql";
    '/var/lib/mysql':
      ensure => directory;
    '/root/.my.cnf':
      owner   => root,
      group   => root,
      content => "[client]\nuser=proxysql\npassword=${proxysql_password}\nprompt = \"\\u@\\h [DB: \\d]> \"\n"
  }

  # we need a fake exec in common with galera nodes to let
  # galera use the `before` statement in the same firewall
  unless defined(Exec['bootstrap_or_join']) {
    exec { 'bootstrap_or_join':
      command     => 'echo',
      path        => '/usr/bin:/bin',
      refreshonly => true;
    }
  }
  unless defined(Exec['join_existing']) {
    exec { 'join_existing':
      command     => 'echo',
      path        => '/usr/bin:/bin',
      refreshonly => true;
    }
  }

}
