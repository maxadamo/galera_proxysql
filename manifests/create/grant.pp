# == Define: galera_proxysql::create::grant
#
define galera_proxysql::create::grant (
  Variant[Array, String] $table,
  $privileges,
  $dbuser,
  $source = $name
  ) {

  mysql_grant { "${dbuser}@${source}/${table}":
    ensure     => present,
    user       => "${dbuser}@${source}",
    table      => $table,
    privileges => $privileges;
  }

}
