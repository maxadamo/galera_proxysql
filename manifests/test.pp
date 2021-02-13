# Class: galera_proxysql::test
#
#
class galera_proxysql::test {


  $test =




  class { 'galera_proxysql':
    root_password    => Sensitive('root'),
    sst_password     => Sensitive('sst'),
    monitor_password => Sensitive('monitor'),
    force_ipv6       => false,
    galera_hosts     =>  {
      'test-galera01.geant.net' => {'ipv4'=>'192.168.1.50'},
      'test-galera02.geant.net' => {'ipv4'=>'192.168.1.51'},
      'test-galera03.geant.net' => {'ipv4'=>'192.168.1.52'}
    },
    proxysql_hosts   => ['192.168.1.101'],
    proxysql_vip     => '192.168.1.100',
    manage_repo      => true,
    manage_lvm       => false;
  }


}
