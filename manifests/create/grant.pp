# == Define: galera_proxysql::create::grant
#
define galera_proxysql::create::grant (
  Variant[Array, String] $table,
  $privileges,
  $dbuser,
  $ensure = present,
  $source = $name
  ) {

  if $caller_module_name != $module_name {
    fail("this define is intended to be called only within ${module_name}")
  }

  mysql_grant { "${dbuser}@${source}/${table}":
    ensure     => $ensure,
    user       => "${dbuser}@${source}",
    table      => $table,
    privileges => $privileges;
  }

}
