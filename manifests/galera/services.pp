# == Class: galera_proxysql::galera::services
#
# This Class manages services
#
#
class galera_proxysql::galera::services {

  assert_private("this class should be called only by ${module_name}")

  xinetd::service { 'galerachk':
    server         => '/usr/bin/clustercheck',
    port           => '9200',
    user           => 'root',
    group          => 'root',
    groups         => 'yes',
    flags          => 'REUSE NOLIBWRAP',
    log_on_success => '',
    log_on_failure => 'HOST',
    require        => [
      File['/root/.my.cnf', '/etc/sysconfig/clustercheck'],
      File_line['clustercheck_one', 'clustercheck_two']
    ];
  }

  # this service is managed through the script galera-wizard.py
  # we can have either mysql and mysql@bootstrap and it creates
  # some problem to handle the service. 
  # service { 'mysql':
  #   ensure   => running,
  #   provider => 'systemd',
  #   enable   => false;
  # }

}
