# temporary workaround until puppetlabs-mysql is fixed
# root privileges ALL is currently looping
function galera_proxysql::root_privileges_workaround (
  Variant[String, Array] $privileges
) >> Array {

  $all_privileges = [
    'ALTER', 'ALTER ROUTINE', 'CREATE', 'CREATE ROLE', 'CREATE ROUTINE',
    'CREATE TABLESPACE', 'CREATE TEMPORARY TABLES', 'CREATE USER', 'CREATE VIEW',
    'DELETE', 'DROP', 'DROP ROLE', 'EVENT', 'EXECUTE', 'FILE', 'INDEX', 'INSERT',
    'LOCK TABLES', 'PROCESS', 'REFERENCES', 'RELOAD', 'REPLICATION CLIENT',
    'REPLICATION SLAVE', 'SELECT', 'SHOW DATABASES', 'SHOW VIEW', 'SHUTDOWN',
    'SUPER', 'TRIGGER', 'UPDATE', 'GRANT OPTION'
  ]

  if $privileges =~ String {
    $privileges_array = [$privileges]
  } else {
    $privileges_array = $privileges
  }

  if $facts['percona_major_version_facts'] and $facts['percona_major_version_facts'] == '80' {
    $final_privileges = $privileges_array.map |$item| {
      if upcase($item) == 'ALL' { $all_privileges } else { $item }
    }
  } else {
    $final_privileges = $privileges_array
  }

  flatten($final_privileges)

}
