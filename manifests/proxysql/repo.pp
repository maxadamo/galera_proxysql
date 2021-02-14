# == Class: galera_proxysql::proxysql::repo inherits galera
#
class galera_proxysql::proxysql::repo ($http_proxy, $manage_repo) {

  assert_private("this class should be called only by ${module_name}")

  if $manage_repo {
    rpmkey { '8507EFA5':
      ensure => present,
      source => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY';
    }
    yumrepo {
      default:
        enabled    => '1',
        gpgcheck   => '1',
        proxy      => $http_proxy,
        mirrorlist => absent,
        gpgkey     => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY',
        require    => Rpmkey['8507EFA5'];
      'proxysql':
        baseurl => 'http://repo.percona.com/proxysql/yum/release/$releasever/RPMS/$basearch',
        descr   => 'ProxySQL';
      'percona-percona':
        baseurl => 'http://repo.percona.com/percona/yum/release/$releasever/RPMS/$basearch',
        descr   => 'Percona';
    }
  }

}
