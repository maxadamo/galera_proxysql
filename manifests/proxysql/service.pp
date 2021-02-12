# == Class: galera_proxysql::proxysql::proxysql
#
# Managed services
# Right now proxysql still uses sysv initscript
# I prefer to get rid of it and use systemd
#
# === Parameters & Variables
#
# None
#
#
class galera_proxysql::proxysql::service ($limitnofile, $proxysql_package) {

  assert_private("this class should be called only by ${module_name}")

  file {
    '/etc/systemd/system/proxysql.service.d':
      ensure => directory;
    '/etc/systemd/system/proxysql.service.d/file_limit.conf':
      content => epp("${module_name}/file_limit.conf.epp"),
      require => File['/etc/systemd/system/proxysql.service.d'],
      notify  => [
        Exec["${module_name}_daemon_reload"],
        Service['proxysql']
      ];
    '/var/lib/proxysql':
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
    provider   => 'systemd',
    require    => File['/etc/systemd/system/proxysql.service.d/file_limit.conf'];
  }

  exec { "${module_name}_daemon_reload":
    refreshonly => true,
    path        => '/usr/bin:/usr/sbin:/bin',
    command     => 'systemctl daemon-reload',
    before      => Service['proxysql'];
  }

}
