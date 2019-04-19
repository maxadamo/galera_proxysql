# galera_proxysql

#### Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with galera_proxysql](#setup)
    * [Beginning with galera_proxysql](#beginning-with-galera_proxysql)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module sets up and bootstrap Galera cluster and ProxySQL.
The status of the cluster is checked at run time through the fact `galera_status` and puppet will attempt to re-join the node in case of disconnection.

If puppet fails to recover a node you can use the script `galera_wizard.py` provided with this module.

ProxySQL will be set up on 2 nodes (no more, no less) with Keepalived and 1 floating IP.

* if you want only the Galera cluster you need _at least_ 3 servers and 3 ipv4 (and optionally 3 ipv6)
* if you want the full stack you need _at least_ 5 servers and 6 IPv4 (and optionally 6 IPv6)

Initial State Snapshot Transfer is supported only through Percona XtraBackup (on average DBs I see no reason to use `mysqldump` or `rsync` since the donor would be unavailable during the transfer: see [Galera Documentation](http://galeracluster.com/documentation-webpages/sst.html)).

The backup script provided by this module is indeed poor, but it can be considered as an example if you want to start using Percona XtraBackup. You could also check Xtrabackup from puppetlabs/mysql

**When bootstrapping, avoid running puppet on all the nodes at same time.** You need to bootstrap one node first.

Read at (actual) **limitations** in the paragraph below.

## Setup

### Beginning with galera_proxysql

Sensitive type for passwords is not mandatory, but it's recommended. If it's not being used the module will emit a notifycation.

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

```puppet
class { '::galera_proxysql::proxysql::proxysql':
  monitor_password => Sensitive($monitor_password),
  trusted_networks => $trusted_networks,
  proxysql_hosts   => $proxysql_hosts,
  proxysql_vip     => $proxysql_vip,
  galera_hosts     => $galera_hosts;
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

## Usage

The module will fail on Galera with an even number of nodes and with a number of nodes lower than 3.

To setup a Galera Cluster (and optionally a ProxySQL cluster with Keepalived) we need a hash. If you use hiera it will be like this:

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

If you do not use ipv6, just skip the `ipv6` keys as following:

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
  dbpass         => Sensitive(lookup('zabbix_db_pass', String, 'first', 'default_pass')),
  galera_hosts   => $galera_hosts,
  proxysql_hosts => $proxysql_hosts,
  proxysql_vip   => $proxysql_hosts,
  privileges     => ['ALL'],
  table          => 'zabbix.*';
}
```

On ProxySQL:

```puppet
galera_proxysql::create::user { 'zabbix':
  dbpass => Sensitive(lookup('zabbix_db_pass', String, 'first', 'zabbix'));
}
```

## Reference

## Limitations

* In order to add SSL on the frontend, I need to add support for ProxySQL 2 (Right now I'm using ProxySQL 1.4.xx)
* not yet tested on ipv4 only (it should work)
* there are too many moving parts and I decided to temporarily remove support to Ubuntu.

## Development

Feel free to make pull requests and/or open issues on [my GitHub Repository](https://github.com/maxadamo/galera_proxysql)

## Release Notes/Contributors/Etc. **Optional**
