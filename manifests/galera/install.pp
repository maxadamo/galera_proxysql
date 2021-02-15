# == Class: galera_proxysql::galera::install
#
# This Class installs all the packages
#
#
class galera_proxysql::galera::install (
  $percona_major_version,
  $percona_minor_version,
  $manage_epel,
  $other_pkgs = $galera_proxysql::params::other_pkgs,
  $pip_pkgs = $galera_proxysql::params::pip_pkgs
) {

  assert_private("this class should be called only by ${module_name}")

  if $manage_epel {
    $require_epel = Class['epel']
  } else {
    $require_epel = undef
  }

  $other_pkgs.each | $pkg | {
    unless defined(Package[$pkg]) {
      package { $pkg:
        require => $require_epel,
        before  => Package[$pip_pkgs];
      }
    }
  }

  unless defined(Package["Percona-XtraDB-Cluster-full-${percona_major_version}"]) {
    package { "Percona-XtraDB-Cluster-full-${percona_major_version}":
      ensure => $percona_minor_version;
    }
  }

  package { $pip_pkgs: provider => 'pip3'; }

}
