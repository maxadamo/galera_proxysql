# == Class: galera_proxysql::proxysql::keepalived
#
class galera_proxysql::proxysql::keepalived (
  $proxysql_hosts    = $::galera_proxysql::params::proxysql_hosts,
  $proxysql_vip      = $::galera_proxysql::params::proxysql_vip,
  $network_interface = $::galera_proxysql::params::network_interface,
  $manage_ipv6       = undef
) inherits galera_proxysql::params {

  $vip_key = inline_template('<% @proxysql_vip.each do |key, value| %><%= key %><% end -%>')
  $proxysql_key_first = inline_template('<% @proxysql_hosts.each_with_index do |(key, value), index| %><% if index == 0 %><%= key %><% end -%><% end -%>')
  $proxysql_key_second = inline_template('<% @proxysql_hosts.each_with_index do |(key, value), index| %><% if index == 1 %><%= key %><% end -%><% end -%>')
  $peer_ip = $::fqdn ? {
    $proxysql_key_first  => $proxysql_hosts[$proxysql_key_second]['ipv4'],
    $proxysql_key_second => $proxysql_hosts[$proxysql_key_first]['ipv4'],
  }

  include ::keepalived
  class { '::galera_proxysql::proxysql::firewall': peer_ip => $peer_ip; }

  keepalived::vrrp::script { 'check_proxysql':
    script   => 'killall -0 proxysql',
    interval => '2',
    weight   => '2';
  }

  if ($manage_ipv6) {
    keepalived::vrrp::instance { 'ProxySQL':
      interface                  => $network_interface,
      state                      => 'BACKUP',
      virtual_router_id          => '50',
      unicast_source_ip          => $::ipaddress,
      unicast_peers              => [$peer_ip],
      priority                   => '100',
      auth_type                  => 'PASS',
      auth_pass                  => 'secret',
      virtual_ipaddress          => "${proxysql_vip[$vip_key]['ipv4']}/${proxysql_vip[$vip_key]['ipv4_subnet']}",
      virtual_ipaddress_excluded => ["${proxysql_vip[$vip_key]['ipv6']}/${proxysql_vip[$vip_key]['ipv6_subnet']}"],
      track_script               => 'check_proxysql';
    }
  } else {
    keepalived::vrrp::instance { 'ProxySQL':
      interface         => $network_interface,
      state             => 'BACKUP',
      virtual_router_id => '50',
      unicast_source_ip => $::ipaddress,
      unicast_peers     => [$peer_ip],
      priority          => '100',
      auth_type         => 'PASS',
      auth_pass         => 'secret',
      virtual_ipaddress => "${proxysql_vip[$vip_key]['ipv4']}/${proxysql_vip[$vip_key]['ipv4_subnet']}",
      track_script      => 'check_proxysql';
    }
  }

}
