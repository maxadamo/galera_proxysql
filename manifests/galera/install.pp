# == Class: galera_proxysql::galera::install
#
# This Class installs all the packages
#
#
class galera_proxysql::galera::install (
  $cluster_pkg_name,
  $percona_major_version,
  $percona_minor_version,
  $manage_epel,
  $devel_pkg_name,
  $other_pkgs = $galera_proxysql::params::other_pkgs,
  $pip_pkgs = $galera_proxysql::params::pip_pkgs
) {

  assert_private("this class should be called only by ${module_name}")

  if $manage_epel {
    $require_epel = Class['epel']
  } else {
    $require_epel = undef
  }

  $percona_pkgs = $other_pkgs + $devel_pkg_name

  $percona_pkgs.each | $pkg | {
    unless defined(Package[$pkg]) {
      package { $pkg:
        require => $require_epel,
        before  => Package[$pip_pkgs];
      }
    }
  }

  unless defined(Package[$cluster_pkg_name]) {
    package { $cluster_pkg_name: ensure => $percona_minor_version; }
  }

  package { $pip_pkgs: provider => 'pip3'; }

  if $percona_major_version == '80' {
    # percona 80 requires a new mysql package which is only available as PIP package
    # in order to install this PIP package gcc is also required
    package { 'mysqlclient':
      require  => Package[$pip_pkgs],
      provider => 'pip3';
    }
  } else {
    package { 'python36-mysql': ensure => present; }
  }

}
