# == Class: galera_proxysql::proxysql::firewall
#
class galera_proxysql::proxysql::firewall ($peer_ip) {

  assert_private("this class should be called only by ${module_name}")

  firewall {
    default:
      action => accept,
      proto  => 'vrrp';
    "200 Allow VRRP inbound from ${peer_ip}":
      chain  => 'INPUT',
      source => $peer_ip;
    '200 Allow VRRP inbound to multicast':
      chain       => 'INPUT',
      destination => '224.0.0.0/8';
    '200 Allow VRRP outbound to multicast':
      chain       => 'OUTPUT',
      destination => '224.0.0.0/8';
    "200 Allow VRRP outbound to ${peer_ip}":
      chain       => 'OUTPUT',
      destination => $peer_ip;
  }

}
