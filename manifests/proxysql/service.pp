# == Class: galera_proxysql::proxysql::service
#
# === Parameters & Variables
#
# None
#
#
class galera_proxysql::proxysql::service ($proxysql_package, $proxysql_logs_destination) {

  assert_private("this class should be called only by ${module_name}")

  file { '/lib/systemd/system/proxysql.service':
    ensure  => absent,
    require => Package[$proxysql_package];
  }
  -> systemd::unit_file { 'proxysql.service':
    content => epp("${module_name}/proxysql.service.epp", {
      proxysql_logs_destination => $proxysql_logs_destination
    }),
    notify  => Service['proxysql'];
  }

  file { '/var/lib/proxysql':
    ensure       => directory,
    owner        => proxysql,
    group        => proxysql,
    recurse      => true,
    recurselimit => 1,
    require      => Package[$proxysql_package];
  }

  service { 'proxysql':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'systemd';
  }

  # temprrary workaround: now the limit is set inside the service file
  file { '/etc/systemd/system/proxysql.service.d':
    ensure  => absent,
    recurse => true,
    force   => true;
  }
  ~> exec { "${module_name}_daemon_reload":
    refreshonly => true,
    path        => '/usr/bin:/usr/sbin:/bin:/sbin',
    command     => 'systemctl daemon-reload',
    before      => Service['proxysql'];
  }

}
