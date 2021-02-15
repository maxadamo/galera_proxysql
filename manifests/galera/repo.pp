# == Class: galera_proxysql::galera::repo inherits galera
#
#
class galera_proxysql::galera::repo ($http_proxy, $manage_repo, $manage_epel) {

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
      'percona-pxc57':
        baseurl => 'http://repo.percona.com/pxc-57/yum/release/$releasever/RPMS/$basearch',
        descr   => 'Percona-PXC57';
      'percona-pxb':
        baseurl => 'http://repo.percona.com/pxb-24/yum/release/$releasever/RPMS/$basearch',
        descr   => 'Percona-ExtraBackup';
      'percona-pt':
        baseurl => 'http://repo.percona.com/pt/yum/release/$releasever/RPMS/$basearch',
        descr   => 'Percona-Toolkit';
      'percona-prel':
        baseurl => 'http://repo.percona.com/prel/yum/release/$releasever/RPMS/noarch',
        descr   => 'Percona-Release';
    }
  }

  if $manage_epel {
    include epel
  }

}
