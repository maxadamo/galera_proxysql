# == Define: galera_proxysql::create::grant
#
define galera_proxysql::create::grant (
  Variant[Array, String] $table,
  $privileges,
  $dbuser,
  Enum['present', 'absent', present, absent] $ensure = present,
  $source = $name
  ) {

  mysql_grant { "${dbuser}@${source}/${table}":
    ensure     => $ensure,
    user       => "${dbuser}@${source}",
    table      => $table,
    privileges => $privileges;
  }

}
