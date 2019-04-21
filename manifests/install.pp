# == Class: galera_proxysql::install
#
# This Class installs all the packages
#
class galera_proxysql::install (
  $other_pkgs            = $::galera_proxysql::params::other_pkgs,
  $percona_major_version = $::galera_proxysql::params::percona_major_version,
  $percona_minor_version = $::galera_proxysql::params::percona_minor_version,
) inherits galera_proxysql::params {

  $pip_pkgs = ['distro', 'pysystemd']

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
