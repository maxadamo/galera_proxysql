# == Class: galera_maxscale::install
#
# This Class installs all the packages
#
class galera_maxscale::install (
  $other_pkgs            = $::galera_maxscale::params::other_pkgs,
  $percona_major_version = $::galera_maxscale::params::percona_major_version,
  ) inherits galera_maxscale::params {

  package {
    $other_pkgs:
      ensure => latest;
    "Percona-XtraDB-Cluster-full-${percona_major_version}":
      ensure => installed;
  }

}
