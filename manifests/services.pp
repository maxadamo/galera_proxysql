# == Class: galera_proxysql::services
#
# This Class manages services
#
class galera_proxysql::services {

  service { 'xinetd':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    provider   => 'systemd',
    require    => Package['xinetd'];
  }

  # mysql.service and mysql@bootstrap.service are mutual exclusives.
  # A proper way to deal with both services must be found.
  # service { 'mysql':
  #   ensure   => running,
  #   provider => 'systemd',
  #   enable   => false;
  # }

}
