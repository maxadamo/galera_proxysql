# == Class: galera_proxysql::repo inherits galera
#
class galera_proxysql::repo ($http_proxy, $manage_repo) {

  assert_private("this manifest should only be called by ${module_name}")

  if $manage_repo {
    rpmkey { 'CD2EFD2A':
      ensure => present,
      source => 'http://www.percona.com/downloads/RPM-GPG-KEY-percona';
    }
    yumrepo { 'percona':
      enabled    => '1',
      gpgcheck   => '1',
      proxy      => $http_proxy,
      mirrorlist => absent,
      baseurl    => "http://repo.percona.com/release/\$releasever/RPMS/\$basearch",
      descr      => 'Percona',
      gpgkey     => 'http://www.percona.com/downloads/RPM-GPG-KEY-percona',
      require    => Rpmkey['CD2EFD2A'];
    }
  }

}
