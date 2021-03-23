# == Class: galera_proxysql::proxysql::keepalived
#
#
class galera_proxysql::proxysql::keepalived (
  $proxysql_hosts,
  $proxysql_vip,
  $network_interface,
  $keepalived_sysconf_options,
  $use_ipv6
) {

  assert_private("this class should be called only by ${module_name}")

  $vip_key = keys($proxysql_vip)[0]
  $proxysql_key_first = keys($proxysql_hosts)[0]
  $proxysql_key_second = keys($proxysql_hosts)[1]
  if $facts['fqdn'] == $proxysql_key_first {
    $priority = 100
    $state = 'MASTER'
    $peer_ip = $proxysql_hosts[$proxysql_key_second]['ipv4']
  } else {
    $priority = 99
    $state = 'BACKUP'
    $peer_ip = $proxysql_hosts[$proxysql_key_first]['ipv4']
  }

  class { 'keepalived': sysconf_options => $keepalived_sysconf_options; }

  class { 'galera_proxysql::proxysql::firewall': peer_ip => $peer_ip; }

  keepalived::vrrp::script { 'check_proxysql':
    script   => 'killall -0 proxysql',
    weight   => 2,  # integer added/removed to/from priority
    rise     => 1,  # required number of OK
    fall     => 1,  # required number of KO
    interval => 2;
  }

  if ($use_ipv6) {
    keepalived::vrrp::instance { 'ProxySQL':
      interface                  => $network_interface,
      state                      => $state,
      virtual_router_id          => seeded_rand(255, "${module_name}${::environment}")+0,
      unicast_source_ip          => $facts['ipaddress'],
      unicast_peers              => [$peer_ip],
      priority                   => $priority+0,
      auth_type                  => 'PASS',
      auth_pass                  => seeded_rand_string(10, "${module_name}${::environment}"),
      virtual_ipaddress          => "${proxysql_vip[$vip_key]['ipv4']}/${proxysql_vip[$vip_key]['ipv4_subnet']}",
      virtual_ipaddress_excluded => ["${proxysql_vip[$vip_key]['ipv6']}/${proxysql_vip[$vip_key]['ipv6_subnet']}"],
      track_script               => 'check_proxysql';
    }
  } else {
    keepalived::vrrp::instance { 'ProxySQL':
      interface         => $network_interface,
      state             => 'BACKUP',
      virtual_router_id => seeded_rand(255, "${module_name}${::environment}")+0,
      unicast_source_ip => $facts['ipaddress'],
      unicast_peers     => [$peer_ip],
      priority          => $priority+0,
      auth_type         => 'PASS',
      auth_pass         => seeded_rand_string(10, "${module_name}${::environment}"),
      virtual_ipaddress => "${proxysql_vip[$vip_key]['ipv4']}/${proxysql_vip[$vip_key]['ipv4_subnet']}",
      track_script      => 'check_proxysql';
    }
  }

}
