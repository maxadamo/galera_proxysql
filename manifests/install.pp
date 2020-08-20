# == Class: galera_proxysql::install
#
# This Class installs all the packages
#
class galera_proxysql::install (
  $other_pkgs,
  $percona_major_version,
  $percona_minor_version,
) {

  assert_private('this manifest should only be called by the module')

  $pip_pkgs = ['distro', 'multiping', 'pysystemd']

  $other_pkgs.each | $pkg | {
    unless defined(Package[$pkg]) {
      package { $pkg: before => Package[$pip_pkgs]; }
    }
  }

  unless defined(Package["Percona-XtraDB-Cluster-full-${percona_major_version}"]) {
    package { "Percona-XtraDB-Cluster-full-${percona_major_version}":
      ensure => $percona_minor_version;
    }
  }

  package { $pip_pkgs: provider => 'pip3'; }

}
