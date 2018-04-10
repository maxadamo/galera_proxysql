# == Class: galera_proxysql::services
#
# This Class manages services
#
class galera_proxysql::services {

  xinetd::service { 'galerachk':
    server         => '/usr/bin/clustercheck',
    port           => '9200',
    user           => 'root',
    group          => 'root',
    groups         => 'yes',
    flags          => 'REUSE',
    log_on_success => '',
    log_on_failure => 'HOST',
    require        => [
      File['/root/.my.cnf', '/etc/sysconfig/clustercheck'],
      File_line['clustercheck_one', 'clustercheck_two']
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
