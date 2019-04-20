# == Define: galera_proxysql::create::root_password
#
# == Overview
#
# if the password was changed on one node, it will fail in the other nodes
# we need to let it fail and check it again, with the new password
#
# the password will be changed only if /root/.my.cnf is available, it the server
# belonged to a cluster and if the cluster status is 200
#
define galera_proxysql::create::root_password(Sensitive $root_pass) {

  $root_cnf = '/root/.my.cnf'

  # I'm not sure when exec started supporting Sensitive data. Switching to files
  file {
    default:
      mode    => '0750',
      require => File['/root/bin'];
    '/root/bin/pw_change.sh':
      content => Sensitive(epp("${module_name}/root_pw/pw_change.sh.epp", {
        'root_cnf'  => $root_cnf,
        'root_pass' => Sensitive($root_pass),
      }));
    '/root/bin/old_pw_check.sh':
      content => epp("${module_name}/root_pw/old_pw_check.sh.epp", { 'root_cnf' => $root_cnf });
    '/root/bin/new_pw_check.sh':
      content => Sensitive(epp("${module_name}/root_pw/new_pw_check.sh.epp", {
        'root_pass' => Sensitive($root_pass)
      }));
  }

  if ($::galera_rootcnf_exist and $::galera_joined_exist and $::galera_status == '200') {
    exec { 'change_root_password':
      require => File[
        '/root/bin/new_pw_check.sh', '/root/bin/old_pw_check.sh', '/root/bin/pw_change.sh'
      ],
      command => 'old_pw_check.sh &>/dev/null && pw_change.sh &>/dev/null',
      path    => '/root/bin',
      unless  => 'new_pw_check.sh &>/dev/null',
      before  => File[$root_cnf];
    }
  }

}
