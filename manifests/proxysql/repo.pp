# == Class: galera_proxysql::proxysql::repo
#
#
class galera_proxysql::proxysql::repo ($http_proxy, $manage_repo, $percona_major_version) {

  assert_private("this class should be called only by ${module_name}")

  if $manage_repo {
    rpmkey { '8507EFA5':
      ensure => present,
      source => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY';
    }
    if $percona_major_version in ['56', '57'] {
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
    } elsif $percona_major_version == '80' {
      yumrepo { 'percona-pdpxc80':
        enabled    => '1',
        gpgcheck   => '1',
        proxy      => $http_proxy,
        mirrorlist => absent,
        gpgkey     => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY',
        require    => Rpmkey['8507EFA5'],
        baseurl    => 'https://repo.percona.com/pdpxc-8.0/yum/release/$releasever/RPMS/$basearch/',
        descr      => 'Percona-PDPXC80';
      }
    }

  }

}
