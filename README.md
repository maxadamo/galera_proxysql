# galera_proxysql

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with galera_proxysql](#setup)
    * [Beginning with galera_proxysql](#beginning-with-galera_proxysql)
    * [Firewall](#firewall)
    * [SSL](#ssl)
1. [Usage](#usage)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Development](#development)
1. [ToDo](#todo)

## Description

This module sets up and bootstrap Galera cluster and ProxySQL.
The status of the cluster is checked at run time through the fact `galera_status` and puppet will attempt to re-join the node in case of disconnection.

If puppet fails to recover a node you can use the script `galera_wizard.py` provided with this module.

ProxySQL will be set up on 2 nodes (no more, no less) with Keepalived and 1 floating IP.

* if you want only the Galera cluster you need _at least_ 3 servers and 3 ipv4 (and optionally 3 ipv6)
* if you want the full stack you need _at least_ 5 servers and 6 IPv4 (and optionally 6 IPv6)

Initial State Snapshot Transfer is supported only through Percona XtraBackup (on average DBs I see no reason to use `mysqldump` or `rsync` since the donor would be unavailable during the transfer: see [Galera Documentation](http://galeracluster.com/documentation-webpages/sst.html)).

Xtrabackup is now supported by puppetlabs/mysql `mysql::backup::xtrabackup`, hence I decided to remove XtraBackup from this module.

**When bootstrapping, avoid running puppet on all the nodes at same time.** You need to bootstrap one node first and then you can join the other nodes.

Read at (actual) **limitations** in the section below.

## Setup

### Beginning with galera_proxysql

Sensitive type for passwords is not mandatory, but it's recommended. If it's not being used you'll see a warning.

To setup Galera:

```puppet
class { '::galera_proxysql':
  root_password    => Sensitive($root_password),
  sst_password     => Sensitive($sst_password),
  monitor_password => Sensitive($monitor_password),
  proxysql_hosts   => $proxysql_hosts,
  proxysql_vip     => $proxysql_vip,
  galera_hosts     => $galera_hosts,
  trusted_networks => $trusted_networks,
  manage_lvm       => true,
  vg_name          => 'rootvg',
  lv_size          => $lv_size;
}
```

To setup ProxySQL:

* with version 2.x SSL is always enabled, but unless otherwise configured, it's optional on the client side, and it can be enabled on a per user basis.

* ProxySQL generates a self-signed certificates. Bear in mind that it will be on each node. If you want to use your own certificates, you can use `manage_ssl` and specify the source for the certificate, CA and private key.

```puppet
class { '::galera_proxysql::proxysql::proxysql':
  manage_ssl           => true,
  ssl_cert_source_path => "puppet:///modules/my_module/${facts['domain']}.crt",
  ssl_ca_source_path   => '/etc/pki/tls/certs/COMODO_OV.crt',
  ssl_key_source_path  => "/etc/pki/tls/private/${facts['domain']}.key",
  monitor_password     => Sensitive($monitor_password),
  trusted_networks     => $trusted_networks,
  proxysql_hosts       => $proxysql_hosts,
  proxysql_vip         => $proxysql_vip,
  galera_hosts         => $galera_hosts;
}
```

Once you have run puppet on every node, you can manage or check the cluster using the script:

```shell
[root@test-galera01 ~]# galera_wizard.py -h
usage: galera_wizard.py [-h] [-cg] [-dr] [-je] [-be] [-jn] [-bn]

Use this script to bootstrap, join nodes within a Galera Cluster
----------------------------------------------------------------
  Avoid joining more than one node at once!

optional arguments:
  -h, --help                 show this help message and exit
  -cg, --check-galera        check if all nodes are healthy
  -dr, --dry-run             show SQL statements to run on this cluster
  -je, --join-existing       join existing Cluster
  -be, --bootstrap-existing  bootstrap existing Cluster
  -jn, --join-new            join existing Cluster
  -bn, --bootstrap-new       bootstrap new Cluster
  -f, --force                force bootstrap-new or join-new Cluster

Author: Massimiliano Adamo <maxadamo@gmail.com>
```

### Firewall

This module include optional settings for iptables.

There are few assumptions connected with the the firewall settings in this module. If you set `manage_firewall` to `true`:

1. The first assumption is that the traffic was closed by iptables between your servers, and this module, will open the ports used by Galera and ProxySQL.

2. The other assumption is that you have already included the firewall module for your servers.

```puppet
include firewall
```

3. if you don't use IPv6, you have disabled this setting for your firewall:

```puppet
class { 'firewall': ensure_v6 => stopped; }
 ```

### SSL

This modules enables SSL offload by default (SSL between ProxySQL and backend is in the [ToDo](#todo) list). As you probably now SSL usage is optional, unless otherwise configured on a per use basis.

You may let proxySQL use its own self-signed certificate, but **beware** of the facts that in this case the certificate will be different on each node of the cluster and you'll have to sync it manually.

Alternatively you can set `manage_ssl` to `true` and specify your own certificates.

## Usage

The module will fail on Galera with an even number of nodes and with a number of nodes lower than 3.

To setup a Galera Cluster (and optionally a ProxySQL cluster with Keepalived) you need a hash declaration. If you use hiera it will be like this:

```yaml
galera_hosts:
  test-galera01.example.net:
    ipv4: '192.168.0.83'
    ipv6: '2001:123:4::6b'
  test-galera02.example.net:
    ipv4: '192.168.0.84'
    ipv6: '2001:123:4::6c'
  test-galera03.example.net:
    ipv4: '192.168.0.85'
    ipv6: '2001:123:4::6d'
proxysql_hosts:
  test-proxysql01.example.net:
    priority: 250              # optional: defaults to 100
    state: 'MASTER'            # optional: defaults to 'BACKUP'
    ipv4: '192.168.0.86'
    ipv6: '2001:123:4::6e'
  test-proxysql02.example.net:
    ipv4: '192.168.0.87'
    ipv6: '2001:123:4::6f'
proxysql_vip:
  test-proxysql.example.net:
    ipv4: '192.168.0.88'
    ipv4_subnet: '22'
    ipv6: '2001:123:4::70'
```

If you do not intend to use ipv6, just skip the `ipv6` keys as following:

```yaml
galera_hosts:
  test-galera01.example.net:
    ipv4: '192.168.0.83'
  test-galera02.example.net:
    ipv4: '192.168.0.84'
  test-galera03.example.net:
... and so on ..
```

you need an array of trusted networks/hosts (a list of ipv4/ipv6 networks/hosts allowed to connect to MySQL socket):

```yaml
trusted_networks:
  - 192.168.0.1/24
  - 2001:123:4::70/64
  - 192.168.1.44
... and so on ...
```

Create a new DB user:
you could also use the puppetlabs/mysql define and class, but with this define you can create DB and user either on the nodes and on proxysql.

On Galera, to create user Zabbix and DB Zabbix:

```puppet
galera_proxysql::create::user { 'zabbix':
  ensure         => present, # defaults to present
  dbpass         => Sensitive(lookup('zabbix_db_pass', String, 'first', 'default_pass')),
  galera_hosts   => $galera_hosts,
  proxysql_hosts => $proxysql_hosts,
  proxysql_vip   => $proxysql_hosts,
  privileges     => ['ALL'],
  table          => ['zabbix.*', 'zobbix.mytable', 'zubbix.*']; # array or string
}
```

On proxySQL, you can use the above statement again (unused rules, such privileges and table will be ignored) or you can use something as following:

```puppet
galera_proxysql::create::user { 'whatever_user':
  dbpass => Sensitive(lookup('my_db_pass', String, 'first', 'nothing_can_be_worse_than_trump'));
}
```

## Reference

## Limitations

* Ubuntu/Debian are still on hold.
* No changelog is available
* I run PDK and Litmus on my own Gitlab instance (even if I use the public Gitlab it would require Docker on Docker. Will it work?)

## Development

Feel free to make pull requests and/or open issues on [my GitHub Repository](https://github.com/maxadamo/galera_proxysql)

## Release Notes/Contributors/Etc. **Optional**

## ToDo

* Upgrade to Percona 8.x
* Optional setting to enable SSL between ProxySQL and backends
