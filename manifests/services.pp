
# == Class: galera_maxscale::services
#
# This Class manages services
#
class galera_maxscale::services {

  xinetd::service { 'galerachk':
    server         => '/usr/bin/clustercheck',
    port           => '9200',
    user           => 'root',
    group          => 'root',
    groups         => 'yes',
    flags          => 'REUSE',
    log_on_success => '',
    log_on_failure => 'HOST',
    require        => File[
      '/usr/bin/clustercheck', '/root/.my.cnf', '/etc/sysconfig/clustercheck'
    ];
  }

  # mysql and mysql@bootstrap are mutual exclusives.
  # A proper way to deal with both services must be found. 
  # service { 'mysql':
  #   ensure   => running,
  #   provider => 'systemd',
  #   enable   => false;
  # }

}
