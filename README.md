# galera_proxysql

#### Table of Contents

1. [Description](#description)
1. [WYGIWYS](#wygiwys)
1. [Setup](#setup)
    * [Beginning with galera_proxysql](#beginning-with-galera_proxysql)
    * [Firewall](#firewall)
    * [SSL](#ssl)
1. [Usage](#usage)
1. [Reference](#reference)
1. [Limitations](#limitations)
1. [Development](#development)
1. [Release Notes](#release-notes)
1. [ToDo](#todo)

## Description

The version 3.x.x of this module is a great leap forward.

* it runs Percona 80, 57 and 56
* it runs ProxySQL 2 with SSL support
* it requires Puppet 6.x or higher

If you want to upgrade your database from 57 to 80, you can read these instructions (along with [Percona official documentation](https://www.percona.com/doc/percona-server/LATEST/upgrading_guide.html)): [upgrade Percona from 5.7 to 8.0](https://gitlab.geant.org/massimiliano.adamo/galera-proxysql/-/wikis/upgrade-Percona-from-5.7-to-8.0).

The status of the cluster is checked at run time through a puppet fact and puppet will attempt to re-join the node in case of disconnection (**if you bring the whole cluster down and you remove /var/lib/mysql/gvwstate.dat from all the servers you have lost your data** because a clean bootstrap will be attempted).

If there is one node alive in the cluster, puppet will always attempt to revert the service from `mysql@bootstrap` to `mysql`, but it won't succeed, until a 2nd node joins the cluster.

If puppet fails to recover a node you can use the script `galera_wizard.py` provided with this module.

ProxySQL will be set up on 2 nodes (no more, no less) with Keepalived and 1 floating IP.

* if you want only the Galera cluster you need _at least_ 3 servers and 3 ipv4 (and optionally 3 ipv6)
* if you want the full stack you need _at least_ 5 servers and 6 IPv4 (and optionally 6 IPv6)

For now this module supports on State Snapshot Transfer, because on average DBs I see no reason to use `mysqldump` or `rsync` (while rsync could be faster, the donor would not be unavailable during the transfer). Please create a PR if you intend to implement other methods.

Xtrabackup is now supported by puppetlabs/mysql `mysql::backup::xtrabackup`, hence I decided to remove any XtraBackup script from this module.

SST does not use password anymore with Percona 8.0 (the next coming version will implement SSL on cluster traffic). 

**When bootstrapping**, avoid running puppet on all the nodes at the same time. You need to bootstrap one node first and then you can join the other nodes (i.e.: you better run puppet on one node at time).

`percona_major_version` is now mandatory, and it can be either '56', '57' or '80'.

## WYGIWYS

What you get is what you see in the Architecture Diagram

you can have more than 3 backends to increase the read speed of the cluster (bearing in mind that it could have side effects on the write speed).

![Screenshot N/A](https://filesender.geant.org/pub/galera_proxysql.png  "Architecture Diagram")

## Setup

### Beginning with galera_proxysql

Sensitive type for passwords is now mandatory.

To setup Galera:

```puppet
class { 'galera_proxysql':
  percona_major_version => '80',
  root_password         => Sensitive($root_password),
  monitor_password      => Sensitive($monitor_password),
  proxysql_hosts        => $proxysql_hosts,
  proxysql_vip          => $proxysql_vip,
  galera_hosts          => $galera_hosts,
  proxysql_port         => 3306,
  trusted_networks      => $trusted_networks,
  manage_lvm            => true,
  vg_name               => 'rootvg',
  lv_size               => $lv_size;
}
```

To setup ProxySQL:

* you can check the information in the [SSL](#ssl) section (paying attention where I mention the self-signed certificates)

```puppet
class { 'galera_proxysql::proxysql::proxysql':
  percona_major_version => '80',
  manage_ssl            => true,
  ssl_cert_source_path  => "puppet:///modules/my_module/${facts['domain']}.crt",
  ssl_ca_source_path    => '/etc/pki/tls/certs/COMODO_OV.crt',
  ssl_key_source_path   => "/etc/pki/tls/private/${facts['domain']}.key",
  monitor_password      => Sensitive($monitor_password),
  trusted_networks      => $trusted_networks,
  proxysql_hosts        => $proxysql_hosts,
  proxysql_vip          => $proxysql_vip,
  galera_hosts          => $galera_hosts;
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

This module includes optional settings for iptables. You can turn the settings on, settin `manage_firewall` to `true`.

There are few assumptions with the firewall:

1. The first assumption is that the traffic was closed by iptables between your servers, and this module, will open the ports used by Galera and ProxySQL. If this was not the case, you don't to need to manage the fiirewall.

2. The other assumption is that you have already included the firewall module for your servers.

```puppet
include firewall
```

3. if you don't use IPv6, you have already disabled this setting for your firewall:

```puppet
class { 'firewall': ensure_v6 => stopped; }
```

### SSL

This module offloads and enables SSL by default (SSL between ProxySQL and backend is in the [ToDo](#todo) list). As you probably know SSL usage is optional on the client side, unless otherwise configured on a per user basis.

You may let proxySQL use its own self-signed certificate, but **beware** that in this case the certificates will be different on each node of the cluster and you'll have to sync them manually.

Alternatively you can set `manage_ssl` to `true` and use your own certificates.

SSL Cluster traffic, is enabled by default, but right now I decided turned to turn it off. I'll put something in the [ToDo](#todo) list.

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

* I run PDK and Litmus on my own Gitlab instance (even if I use the public Gitlab it would require Docker on Docker. Will it work?). If you want Travis, you need your help me.

|  | RedHat/CentOS  |Debian | Ubuntu LTS |
| :---     |  :---: |  :---: |  :---: |
| **Percona XtraDB Cluster** | 7 | 10 | 18.04 / 20.04 |
| 5.6 / 5.7 / 8.0 | :white_check_mark: **/** :white_check_mark: **/** :white_check_mark: | :no_entry_sign: **/** :no_entry_sign: **/** :no_entry_sign: | :no_entry_sign: **/** :no_entry_sign: **/** :no_entry_sign: |
| **ProxySQL Galera** |  |
| 1.x / 2.x | :no_entry_sign: **/** :white_check_mark: | :no_entry_sign: **/** :no_entry_sign: |  :no_entry_sign: **/** :no_entry_sign: |

## Development

Feel free to make pull requests and/or open issues on [my Gitlab Repository](https://gitlab.geant.org/massimiliano.adamo/galera-proxysql)

## Release Notes

* upgrade to ProxySQL-2 and Percona 80
* offloading and enabling SSL on ProxySQL
* boosted Unit Test

## ToDo

* optional setting to enable SSL cluster traffic
* Optional setting to enable SSL between ProxySQL and backends
* allow more customizations on proxysql.cnf. Right now `max_writers 1` in combination with `writer is also reader` is being used.
