# == Class: galera_proxysql::firewall
#
# sets firewall up to allow comunication within the cluster
#
#
class galera_proxysql::firewall (
  $use_ipv6,
  $galera_hosts,
  $proxysql_hosts,
  $proxysql_vip,
  $trusted_networks,
  $proxysql_port,
) {

  assert_private("this class should be called only by ${module_name}")

  unless defined(Class['firewall']) {
    fail("if you want to use the Firewall from ${module_name}, you need to load the firewall class in advance")
  }

  unless ($proxysql_port) {
    notify { 'using default port 3306 for ProxySQL':
      message => 'using default port 3306 for ProxySQL. TO SUPPRESS THIS WARNING force the parameter $proxysql_port, even for 3306'
    }
    $proxysql_port_final = 3306
  } else {
    $proxysql_port_final = $proxysql_port
  }

  $proxysql_cluster = deep_merge($proxysql_hosts, $proxysql_vip)
  $whole_cluster = deep_merge($proxysql_cluster, $galera_hosts)
  $all_ports = unique([3306, 9200] + $proxysql_port_final)
  $all_ports_string = join($all_ports, ', ')

  $trusted_networks.each | String $source | {
    if $source =~ Stdlib::IP::Address::V6 { $provider = 'ip6tables' } else { $provider = 'iptables' }
    firewall { "200 Allow inbound Galera ports ${proxysql_port_final} from ${source} for ${provider}":
      chain    => 'INPUT',
      source   => $source,
      dport    => $proxysql_port_final,
      proto    => tcp,
      action   => accept,
      provider => $provider;
    }
  }

  $whole_cluster.each | $name, $node | {
    firewall {
      default:
        dport    => $all_ports,
        proto    => tcp,
        action   => accept,
        provider => 'iptables';
      "200 Allow outbound ports ${all_ports_string} on ipv4 to ${name}":
        chain       => 'OUTPUT',
        destination => $node['ipv4'];
      "200 Allow inbound ports ${all_ports_string} on ipv4 from ${name}":
        chain  => 'INPUT',
        source => $node['ipv4'];
    }
    if has_key($node, 'ipv6') {
      firewall {
        default:
          dport    => $all_ports,
          proto    => tcp,
          action   => accept,
          provider => 'ip6tables';
        "200 Allow outbound ports ${all_ports_string} on ipv6 to ${name}":
          chain       => 'OUTPUT',
          destination => $node['ipv6'];
        "200 Allow inbound ports ${all_ports_string} on ipv6 from ${name}":
          chain  => 'INPUT',
          source => $node['ipv6'];
      }
    }
  }

  $galera_hosts.each | $name, $node | {
    firewall {
      default:
        dport    => [4444, 4567, 4568],
        proto    => tcp,
        action   => accept,
        provider => 'iptables';
      "200 Allow outbound Galera ports ipv4 to ${name}":
        chain       => 'OUTPUT',
        destination => $node['ipv4'];
      "200 Allow inbound Galera ports ipv4 from ${name}":
        chain  => 'INPUT',
        source => $node['ipv4'];
    }
    if has_key($node, 'ipv6') {
      firewall {
        default:
          dport    => [4444, 4567, 4568],
          proto    => tcp,
          action   => accept,
          provider => 'ip6tables';
        "200 Allow outbound Galera ports ipv6 to ${name}":
          chain       => 'OUTPUT',
          destination => $node['ipv6'];
        "200 Allow inbound Galera ports ipv6 from ${name}":
          chain  => 'INPUT',
          source => $node['ipv6'];
      }
    }
  }

  unless any2bool($use_ipv6) == false {
    ['iptables', 'ip6tables'].each | String $myprovider | {
      firewall { "200 Allow outbound Galera ports (v4/v6) for ${myprovider}":
        chain    => 'OUTPUT',
        dport    => [3306, 9200],
        proto    => tcp,
        action   => accept,
        provider => $myprovider;
      }
    }
  } else {
    firewall { '200 Allow outbound Galera ports for IPv4':
      chain    => 'OUTPUT',
      dport    => [3306, 9200],
      proto    => tcp,
      action   => accept,
      provider => 'iptables';
    }
  }


  # ProxySQL rules: let's open all the ports across Keepalived hosts
  $proxysql_cluster.each | $name, $node | {
    firewall {
      default:
        action   => accept,
        proto    => tcp,
        dport    => '1-65535',
        provider => 'iptables';
      "200 Allow inbound tcp ipv4 from ${name}":
        chain  => 'INPUT',
        source => $node['ipv4'];
      "200 Allow outbound tcp ipv4 to ${name}":
        chain       => 'OUTPUT',
        destination => $node['ipv4'];
      "200 Allow inbound udp ipv4 to ${name}":
        chain  => 'INPUT',
        source => $node['ipv4'],
        proto  => udp;
      "200 Allow outbound udp ipv4 from ${name}":
        chain       => 'OUTPUT',
        destination => $node['ipv4'],
        proto       => udp;
    }
    if has_key($node, 'ipv6') {
      firewall {
        default:
          action   => accept,
          proto    => tcp,
          dport    => '1-65535',
          provider => 'ip6tables';
        "200 Allow inbound tcp ipv6 from ${name}":
          chain  => 'INPUT',
          source => $node['ipv6'];
        "200 Allow outbound tcp ipv6 to ${name}":
          chain       => 'OUTPUT',
          destination => $node['ipv6'];
        "200 Allow inbound udp ipv6 from ${name}":
          chain  => 'INPUT',
          source => $node['ipv6'],
          proto  => udp;
        "200 Allow outbound udp ipv6 to ${name}":
          chain       => 'OUTPUT',
          destination => $node['ipv6'],
          proto       => udp;
      }
    }
  }

}
