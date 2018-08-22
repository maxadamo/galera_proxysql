# == Define: galera_proxysql::create::root_password
#
# == Overview
#
# if the password was changed on one node, it will fail in the other nodes
# we need to let it fail and check it again, with the new password
#
# the password will be change only if /root/.my.cnf is available, it the server
# belonged to a cluster and if the cluster status is 200
#
define galera_proxysql::create::root_password () {

  $root_password = $name
  $root_cnf = '/root/.my.cnf'
  $pw_change_cmd = "mysqladmin -u root --\$(grep 'password=' ${root_cnf}) password ${root_password}"
  $old_pw_check = "mysql -u root --\$(grep 'password=' ${root_cnf}) -e \"select 1 from dual\""
  $new_pw_check = "mysql -u root --password=${root_password} -e \"select 1 from dual\""

  if ($::galera_rootcnf_exist and $::galera_joined_exist and $::galera_status == '200') {
    exec { 'change_root_password':
      command => "${old_pw_check} && ${pw_change_cmd}",
      path    => '/usr/bin:/usr/sbin:/bin',
      unless  => $new_pw_check,
      before  => File[$root_cnf];
    }
  }

}
