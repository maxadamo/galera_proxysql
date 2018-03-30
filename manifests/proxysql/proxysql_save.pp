# == Class: galera_proxysql::proxysql::proxysql
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
class galera_proxysql::proxysql::proxysql (
  String $percona_major_version = $::galera_proxysql::params::percona_major_version,
  Hash $galera_hosts            = $::galera_proxysql::params::galera_hosts,
  Boolean $manage_repo          = $::galera_proxysql::params::manage_repo,
  Hash $proxysql_hosts          = $::galera_proxysql::params::proxysql_hosts,
  Hash $proxysql_vip            = $::galera_proxysql::params::proxysql_vip,
  String $monitor_password      = $::galera_proxysql::params::monitor_password,
  String $proxy_admin_password  = $::galera_proxysql::params::proxy_admin_password,
  Hash $proxysql_users          = $::galera_proxysql::params::sqlproxy_users,
  Array $trusted_networks       = $::galera_proxysql::params::trusted_networks,
  String $network_interface     = $::galera_proxysql::params::network_interface,
  String $proxysql_version      = $::galera_proxysql::params::proxysql_version,
  $http_proxy                   = $::galera_proxysql::params::http_proxy,
  ) inherits galera_proxysql::params {

  $proxysql_key_first = inline_template('<% @proxysql_hosts.each_with_index do |(key, value), index| %><% if index == 0 %><%= key %><% end -%><% end -%>')
  $vip_key = inline_template('<% @proxysql_vip.each do |key, value| %><%= key %><% end -%>')
  $vip_ip = $proxysql_vip[$vip_key]['ipv4']
  if has_key($proxysql_hosts[$proxysql_key_first], 'ipv6') {
    $ipv6_true = true
  } else {
    $ipv6_true = undef
  }

  class {
    '::galera_proxysql::repo':
      http_proxy  => $http_proxy,
      manage_repo => $manage_repo;
    '::galera_proxysql::proxysql::keepalived':
      manage_ipv6       => $ipv6_true,
      proxysql_hosts    => $proxysql_hosts,
      network_interface => $network_interface,
      proxysql_vip      => $proxysql_vip;
    '::galera_proxysql::firewall':
      manage_ipv6      => $ipv6_true,
      galera_hosts     => $galera_hosts,
      proxysql_hosts   => $proxysql_hosts,
      proxysql_vip     => $proxysql_vip,
      trusted_networks => $trusted_networks;
    '::mysql::client':
      package_name => "Percona-XtraDB-Cluster-client-${percona_major_version}";
  }

  service { 'proxysql':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'systemd',
    require    => Package['proxysql'];
  }

  unless any2bool($manage_repo) == false {
    package {
      default:
        require => Yumrepo['Percona'];
      '::mysql::client':
        ensure => installed,
        before => Class['::mysql::client'];
      'proxysql':
        ensure  => $proxysql_version,
        require => Class['::mysql::client'];
    }
  } else {
    package {
      "Percona-Server-shared-compat-${percona_major_version}":
        ensure => installed,
        before => Class['::mysql::client'];
      'proxysql':
        ensure  => $proxysql_version,
        require => Class['::mysql::client'];
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
      notify  => Service['proxysql'],
      content => template("${module_name}/proxysql.cnf.erb");
    '/etc/init.d/proxysql':
      ensure => absent,
      notify => Exec['kill_to_replace_init_script'];
    '/lib/systemd/system/proxysql.service':
      ensure => file,
      owner  => root,
      group  => root,
      notify => Exec['proxysql_daemon_reload'],
      source => "puppet:///modules/${module_name}/proxysql.service";
    '/var/lib/mysql':
      ensure => directory;
    '/root/.my.cnf':
      owner   => root,
      group   => root,
      content => "[client]\nuser=monitor\npassword=${monitor_password}\nprompt = \"\\u@\\h [DB: \\d]> \"\n"
  }

  concat { '/etc/proxysql.cnf':
    owner  => 'proxysql',
    group  => 'proxysql',
    mode   => '0644',
    notify => Service['proxysql'];
  }

  concat::fragment {
    'proxysql_cnf_header':
      target  => '/etc/proxysql.cnf',
      content => template("${module_name}/proxysql_cnf/header.cnf.erb"),
      order   => '1';
    'proxysql_cnf_footer':
      target  => '/etc/proxysql.cnf',
      content => template("${module_name}/proxysql_cnf/footer.cnf.erb"),
      order   => '999999999';
  }

  $proxysql_users.each | $sqluser, $sqlpass | {
    concat::fragment { $sqluser:
      target  => '/etc/proxysql.cnf',
      content => ",{\n    username = \"${sqluser}\"\n    password = \"${sqlpass}\"\n    default_hostgroup = 0\n    active = 1\n  }",
      order   => fqdn_rand(999999998, "${sqluser}${sqlpass}")+1;
    }
  }


  exec {
    default:
      path        => '/usr/bin:/usr/sbin:/bin:/usr/local/bin';
    'proxysql_daemon_reload':
      command     => 'systemctl daemon-reload',
      refreshonly => true;
    'kill_to_replace_init_script':
      command     => 'pkill -f -9 proxysql',
      returns     => [0, 1],
      refreshonly => true;
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