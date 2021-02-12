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
define galera_proxysql::create::root_password(Sensitive $root_pass, Boolean $force_ipv6) {

  $root_cnf = '/root/.my.cnf'
  if ($force_ipv6) {
    $root_host_list = ['127.0.0.1', 'localhost', '::1']
  } else {
    $root_host_list = ['127.0.0.1', 'localhost']
  }

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

  if ($facts['galera_rootcnf_exist'] and $facts['galera_joined_exist'] and $facts['galera_status'] == '200') {
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

  # the code below is needed if the user wants to set mysql_grant purge to true
  # it won't work in a perfect way but at least it won't break MySQL
  $root_host_list.each | $local_host | {
    mysql_grant { "root@${local_host}/*.*":
      ensure     => present,
      user       => "root@${local_host}",
      table      => '*.*',
      privileges => ['ALL', 'SUPER'],
      require    => File[$root_cnf];
    }
  }

  mysql_grant { 'mysql.session@localhost/performance_schema.*':
    ensure     => present,
    user       => 'mysql.session@localhost',
    table      => 'performance_schema.*',
    privileges => 'SELECT',
    require    => File[$root_cnf];
  }

}
