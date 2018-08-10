# == Class: galera_proxysql::backup
#
# This Class sets up a daily hot-backup
# You may need to provide sufficient space in the mount point $backup_dir.
#
# The backup will run only on one node: I decided to pick the 2nd node.
#
#
class galera_proxysql::backup (
  $galera_hosts        = $::galera_proxysql::params::galera_hosts,
  $daily_hotbackup     = $::galera_proxysql::params::daily_hotbackup,
  $galera_cluster_name = $::galera_proxysql::params::galera_cluster_name,
  $backup_dir          = $::galera_proxysql::params::backup_dir,
) {

  $nodes = keys($galera_hosts)

  if ($daily_hotbackup) {
    $ensure = 'present'
    notify { '2nd node of the cluster: setting up daily hot-backup': }
  } else {
    $ensure = 'absent'
  }

  exec { 'make_backup_dir':
    command => "mkdir -p ${backup_dir}/${galera_cluster_name}",
    path    => '/usr/bin:/usr/sbin:/bin',
    unless  => "test -d ${backup_dir}/${galera_cluster_name}"
  }

  # Crontab entry to run daily backups only on the second node
  if $::fqdn == (inline_template('<%= @nodes.sort[1] %>')) {
    cron { "${galera_cluster_name}-${::hostname}-backup-script":
      ensure  => $ensure,
      command => '/root/bin/hotbackup.sh',
      user    => 'root',
      hour    => fqdn_rand(7),
      minute  => fqdn_rand(60),
    }
  }

}
