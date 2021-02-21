# == Define: galera_proxysql::create::grant
#
#
define galera_proxysql::create::grant (
  $table,
  $privileges,
  $dbuser,
  $source,
  $ensure = present,
) {

  assert_private("this define should be called only by ${module_name}")

  if $table =~ String {
    mysql_grant { "${dbuser}@${source}/${table}":
      ensure     => $ensure,
      user       => "${dbuser}@${source}",
      table      => $table,
      privileges => $privileges;
    }
  } else {
    $table.each | $table_item | {
      mysql_grant { "${dbuser}@${source}/${table_item}":
        ensure     => $ensure,
        user       => "${dbuser}@${source}",
        table      => $table_item,
        privileges => $privileges;
      }
    }
  }

}
