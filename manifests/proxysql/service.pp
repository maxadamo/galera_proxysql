# == Class: galera_proxysql::proxysql::proxysql
#
# Managed services
#
# === Parameters & Variables
#
# None
#
#
class galera_proxysql::proxysql::service {

  file {
    '/etc/init.d/proxysql':
      ensure  => absent,
      notify  => Exec['kill_to_replace_init_script'],
      require => Package['proxysql'];
    '/lib/systemd/system/proxysql.service':
      owner   => root,
      group   => root,
      require => File['/etc/init.d/proxysql'],
      notify  => [Exec["${module_name}_daemon_reload"], Service['proxysql']],
      source  => "puppet:///modules/${module_name}/proxysql.service";
  }

  service { 'proxysql':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'systemd',
    require    => File['/lib/systemd/system/proxysql.service'];
  }

  if ($::ipaddress6) {
    package { 'socat': ensure => installed; }
    -> file { '/lib/systemd/system/mysql_forwarder.service':
      owner   => root,
      group   => root,
      notify  => Exec["${module_name}_daemon_reload"],
      content => template("${module_name}/mysql_forwarder.service.erb");
    }
    -> service { 'mysql_forwarder':
      ensure     => running,
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      provider   => 'systemd';
    }
  }

  exec {
    default:
      refreshonly => true,
      path        => '/usr/bin:/usr/sbin:/bin';
    "${module_name}_daemon_reload":
      command => 'systemctl daemon-reload',
      before  => Service['mysql_forwarder', 'proxysql'];
    'kill_to_replace_init_script':
      command => 'pkill -f -9 proxysql',
      returns => [0, 1];
  }

}
