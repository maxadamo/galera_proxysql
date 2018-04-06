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
class galera_proxysql::proxysql::service (
  $limitnofile = $::galera_proxysql::params::limitnofile,
  ) {

  file {
    '/etc/init.d/proxysql':
      ensure  => absent,
      notify  => Exec['kill_to_replace_init_script'],
      require => Package['proxysql'];
    '/lib/systemd/system/proxysql.service':
      owner   => root,
      group   => root,
      require => File['/etc/init.d/proxysql'],
      notify  => [
        Exec["${module_name}_daemon_reload"],
        Service['proxysql']
      ],
      source  => "puppet:///modules/${module_name}/proxysql.service";
    '/etc/systemd/system/proxysql.service.d':
      ensure => directory;
    '/etc/systemd/system/proxysql.service.d/file_limit.conf':
      content => template("${module_name}/file_limit.conf.erb"),
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
      recurselimit => 0,
      require      => Package['proxysql'];
  }

  service { 'proxysql':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'systemd',
    require    => File[
      '/lib/systemd/system/proxysql.service',
      '/etc/systemd/system/proxysql.service.d/file_limit.conf'
    ];
  }

  exec {
    default:
      refreshonly => true,
      path        => '/usr/bin:/usr/sbin:/bin';
    "${module_name}_daemon_reload":
      command => 'systemctl daemon-reload',
      before  => Service['proxysql'];
    'kill_to_replace_init_script':
      command => 'pkill -f -9 proxysql',
      returns => [0, 1];
  }

}
