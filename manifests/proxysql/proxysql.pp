# == Class: galera_proxysql::proxysql::proxysql
#
# === Parameters & Variables
#
# [*galera_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to the cluster: not less than 3, not even.
#   check examples on README.md
#
# [*http_proxy*] <String>
#   default: undef  http proxy used for instance by gpg key
#   Example: 'http://proxy.example.net:8080'
#
# [*manage_repo*] <Bool>
#   default: true => please check repo.pp to understand what repos are neeeded
#
# [*proxysql_hosts*] <Hash>
#   list of hosts, ipv4 (optionally ipv6) belonging to ProxySQL cluster.
#   Currently only 2 hosts are supported. Check examples on README.md
#
# [*keepalived_sysconf_options*] <String>
#   list of options to pass to keepalived. Example: -D --snmp
#   default: => '-D'
#
# [*proxysql_admin_password*] <Sensitive>
#   proxysql user password
#
# [*proxysql_port*] <Stdlib::Port>
#   default: 3306 => ProxySQL TCP port
#
# [*proxysql_vip*] <Hash>
#   host, ipv4 (optionally ipv6) for the VIP
#
# [*trusted_networks*] <Array>
#   default: undef => List of IPv4 and/or IPv6 host and or networks.
#            It's used by iptables to determine from where to allow access to MySQL
#
# [*manage_ssl*] <Boolean>
#   default: undef => Use your own certificate or use self-signed
#  *BEWARE*: if you leave manage_ssl undef, you'll use a self-signed certificate and
#            it will be different on each node of the cluster. You may need to synchronize
#            them manually, but they are valid for 10 years and I know that you can afford it :-)
#
# [*ssl_ca_source_path*] <Stdlib::Filesource>
#   default: undef => it's mandatory if manage_ssl is true
#            it can be a local path on the server or a path like: puppet:///modules/...
#
# [*ssl_cert_source_path*] <Stdlib::Filesource>
#   default: undef => it's mandatory if manage_ssl is true
#            it can be a local path on the server or a path like: puppet:///modules/...
#
# [*ssl_key_source_path*] <Stdlib::Filesource>
#   default: undef => it's mandatory if manage_ssl is true
#            it can be a local path on the server or a path like: puppet:///modules/...
#
# [*manage_firewall*] <Bool>
#   default: false => It requires puppetlabs/firewall
#
#
class galera_proxysql::proxysql::proxysql (

  # SSL settings
  # *BEWARE* if you leave manage_ssl set to undef, you get two self-signed certificates on each node
  # different from each other. You may want to synchronize them manually (they are valid for 10 years)
  Boolean $manage_ssl                                = undef,  # use the default self-signed
  Optional[Stdlib::Filesource] $ssl_ca_source_path   = $galera_proxysql::params::ssl_ca_source_path,
  Optional[Stdlib::Filesource] $ssl_cert_source_path = $galera_proxysql::params::ssl_cert_source_path,
  Optional[Stdlib::Filesource] $ssl_key_source_path  = $galera_proxysql::params::ssl_key_source_path,

  # PRoxySQL general settings
  Optional[String] $keepalived_sysconf_options         = $galera_proxysql::params::keepalived_sysconf_options,
  $proxysql_users                                      = undef,  # users are now created through galera_proxysql::create::user
  Stdlib::Port $proxysql_port                          = $galera_proxysql::params::proxysql_port,
  Stdlib::Port $proxysql_admin_port                    = $galera_proxysql::params::proxysql_admin_port,
  Enum['56', '57', '80'] $percona_major_version        = $galera_proxysql::params::percona_major_version,
  Boolean $force_ipv6                                  = $galera_proxysql::params::force_ipv6,
  Hash $galera_hosts                                   = $galera_proxysql::params::galera_hosts,
  Boolean $manage_repo                                 = $galera_proxysql::params::manage_repo,
  Hash $proxysql_hosts                                 = $galera_proxysql::params::proxysql_hosts,
  Hash $proxysql_vip                                   = $galera_proxysql::params::proxysql_vip,
  Array $trusted_networks                              = $galera_proxysql::params::trusted_networks,
  String $network_interface                            = $galera_proxysql::params::network_interface,
  String $proxysql_package                             = $galera_proxysql::params::proxysql_package,
  String $proxysql_version                             = $galera_proxysql::params::proxysql_version,
  String $proxysql_mysql_version                       = $galera_proxysql::params::proxysql_mysql_version,
  $http_proxy                                          = $galera_proxysql::params::http_proxy,
  Boolean $manage_firewall                             = $galera_proxysql::params::manage_firewall,
  Integer $set_query_lock_on_hostgroup                 = $galera_proxysql::params::set_query_lock_on_hostgroup,
  Enum['journal', 'syslog'] $proxysql_logs_destination = $galera_proxysql::params::proxysql_logs_destination,

  # Passwords
  Sensitive $monitor_password        = $galera_proxysql::params::monitor_password,
  Sensitive $proxysql_admin_password = $galera_proxysql::params::proxysql_admin_password,

) inherits galera_proxysql::params {

  if ($proxysql_users) {
    fail('please re-use the same galera_proxysql::create::user resource used on Galera to create users even on ProxySQL')
  }

  if ($manage_ssl) {
    if !($ssl_ca_source_path) or !($ssl_cert_source_path) or !($ssl_key_source_path) {
      fail('if you set manage_ssl, you also need to set ssl_ca_source_path, ssl_cert_source_path and ssl_key_source_path')
    }
    class { 'galera_proxysql::proxysql::ssl':
      ssl_ca_source_path   => $ssl_ca_source_path,
      ssl_cert_source_path => $ssl_cert_source_path,
      ssl_key_source_path  => $ssl_key_source_path;
    }
  }

  if $proxysql_port == $proxysql_admin_port {
    fail('proxysql_port and proxysql_admin_port cannot be the same')
  }

  $proxysql_key_first = keys($proxysql_hosts)[0]
  $vip_key = keys($proxysql_vip)[0]
  $vip_ip = $proxysql_vip[$vip_key]['ipv4']
  if has_key($proxysql_hosts[$proxysql_key_first], 'ipv6') {
    $ipv6_true = true
  } else {
    $ipv6_true = undef
  }

  $cluster_shared_pkg_name = $percona_major_version ? {
    '80' => 'percona-xtradb-cluster-shared-compat',
    default => "Percona-XtraDB-Cluster-shared-compat-${percona_major_version}"
  }
  $client_pkg_name = $percona_major_version ? {
    '80' => 'percona-xtradb-cluster-client',
    default => "Percona-XtraDB-Cluster-client-${percona_major_version}"
  }

  $list_top = "    {
        address = \""
  $list_bottom = "\"
        port = 3306
        hostgroup = 10
        status = \"ONLINE\"
        weight = 1
        compression = 0
        max_replication_lag = 0
    },\n"
  $galera_keys = keys($galera_hosts)
  if ($force_ipv6) {
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv6'] }
  } else {
    $transformed_data = $galera_keys.map |$items| { $galera_hosts[$items]['ipv4'] }
  }

  $_server_list = join($transformed_data, "${list_bottom}${list_top}")
  $server_list = "${list_top}${_server_list}${list_bottom}".chop()

  class {
    'galera_proxysql::proxysql::repo':
      percona_major_version => $percona_major_version,
      http_proxy            => $http_proxy,
      manage_repo           => $manage_repo;
    'galera_proxysql::proxysql::service':
      proxysql_package          => $proxysql_package,
      proxysql_logs_destination => $proxysql_logs_destination;
    'galera_proxysql::proxysql::keepalived':
      use_ipv6                   => $ipv6_true,
      proxysql_hosts             => $proxysql_hosts,
      network_interface          => $network_interface,
      keepalived_sysconf_options => $keepalived_sysconf_options,
      proxysql_vip               => $proxysql_vip;
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

  exec {
    default:
      path => '/usr/bin:/bin';
    'clear_proxysqlONE':
      command  => 'yum reinstall -y proxysql; yum remove -y proxysql',
      provider => shell,
      before   => Package[$proxysql_package],
      creates  => '/usr/bin/proxysql-login-file';  # this file belongs to proxysql2 only
    'reset_proxysql_configuration':
      command     => 'rm -f /var/lib/proxysql/proxysql.db',
      refreshonly => true,
      notify      => Service['proxysql'];
  }

  package {
    $cluster_shared_pkg_name:
      ensure  => installed,
      require => Class['galera_proxysql::proxysql::repo'],
      before  => [Class['mysql::client'], Package['keepalived']];
    $proxysql_package:
      ensure  => $proxysql_version,
      notify  => Service['proxysql'],
      require => Class['mysql::client', 'galera_proxysql::proxysql::repo'];
  }

  file {
    default:
      owner => root,
      group => root;
    '/usr/bin/proxysql_galera_checker':
      mode    => '0755',
      require => Package[$proxysql_package],
      notify  => Service['proxysql'],
      content => epp("${module_name}/proxysql_galera_checker.epp", { proxysql_admin_port => $proxysql_admin_port });
    '/var/lib/mysql':
      ensure  => directory,
      owner   => proxysql,
      group   => proxysql,
      require => Package[$proxysql_package],
      notify  => Service['proxysql'];
    '/root/.my.cnf':
      mode    => '0660',
      content => Sensitive("[client]\nuser=monitor\npassword=${monitor_password.unwrap}\nprompt = \"\\u@\\h [DB: \\d]> \"\n");
    '/etc/proxysql-admin.cnf':
      mode    => '0640',
      owner   => proxysql,
      group   => proxysql,
      require => Package[$proxysql_package],
      notify  => Service['proxysql'],
      content => Sensitive(epp("${module_name}/proxysql-admin.cnf.epp", {
        proxysql_port           => $proxysql_port,
        proxysql_admin_port     => $proxysql_admin_port,
        monitor_password        => Sensitive($monitor_password),
        proxysql_admin_password => Sensitive($proxysql_admin_password)
      }));
    '/var/lib/proxysql/.my-admin.cnf':
      mode    => '0640',
      owner   => proxysql,
      group   => proxysql,
      require => Package[$proxysql_package],
      content => Sensitive("[client]\nuser=admin\npassword=admin\nport=${proxysql_admin_port}\nhost=127.0.0.1\nprotocol=tcp\n")
  }

  concat { '/etc/proxysql.cnf':
    owner   => proxysql,
    group   => proxysql,
    mode    => '0640',
    order   => 'numeric',
    require => Package[$proxysql_package],
    notify  => Exec['reset_proxysql_configuration'];
  }

  concat::fragment {
    'proxysql_cnf_header':
      target  => '/etc/proxysql.cnf',
      content => epp("${module_name}/proxysql_header.cnf.epp", {
        proxysql_port               => $proxysql_port,
        proxysql_admin_port         => $proxysql_admin_port,
        proxysql_admin_password     => Sensitive($proxysql_admin_password),
        proxysql_mysql_version      => $proxysql_mysql_version,
        monitor_password            => Sensitive($monitor_password),
        server_list                 => $server_list,
        set_query_lock_on_hostgroup => $set_query_lock_on_hostgroup
      }),
      order   => '1';
    'proxysql_cnf_footer':
      target  => '/etc/proxysql.cnf',
      content => epp("${module_name}/proxysql_footer.cnf.epp"),
      order   => '999999999';
  }

}
