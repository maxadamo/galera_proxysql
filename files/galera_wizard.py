#!/usr/bin/env python3
#
'''
1. This script will either:
  - bootstrap a new or an existing cluster
  - join/rejoin an existing cluster
2. Requirements (normally installed thru puppet):
  - yum install python-argparse MySQL-python
3. Avoid joining all nodes at once
4. The paramter file contains credentials and will be stored inside /root/

Bugs & Workarounds:
1.  We have a bug in Innobackupex:
      - https://bugs.launchpad.net/percona-xtrabackup/+bug/1272329
    A possible solution can come here:
      - https://bugs.launchpad.net/percona-xtrabackup/2.2/+bug/688717
    I prefear using the default directory rather than moving to a subdirectory.
    Therefore we workaround the issue by letting puppet install an incron
    entry that immediately reassign the directory ownership to mysql:mysql

TODO: (see TODO.txt)

Author: Massimiliano Adamo <massimiliano.adamo@gant.org>
'''
import subprocess
import argparse
import textwrap
import socket
import shutil
import signal
import glob
import pwd
import grp
import os
import ast
import configparser
import ipaddress
from warnings import filterwarnings
from multiping import MultiPing
import distro
import MySQLdb
import pysystemd

FORCE = False
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
WHITE = '\033[0m'
CONFIG = configparser.RawConfigParser()
_ = CONFIG.read('/root/galera_params.ini')
try:
    GALERA_NODES = ast.literal_eval(CONFIG.get('galera', 'GALERA_NODES'))
    CREDENTIALS = ast.literal_eval(CONFIG.get('galera', 'CREDENTIALS'))
    MYIP = ast.literal_eval(CONFIG.get('galera', 'MYIP'))
    PERCONA_MAJOR_VERSION = ast.literal_eval(CONFIG.get('galera', 'PERCONA_MAJOR_VERSION'))
except configparser.NoOptionError:
    print("{}Could not access values in /root/galera_params.ini{}".format(RED, WHITE))
    os.sys.exit(1)

OTHER_NODES = list(GALERA_NODES)
OTHER_NODES.remove(MYIP)
OTHER_WSREP = []
REMAINING_NODES = []
LASTCHECK_NODES = []
for item in OTHER_NODES:
    OTHER_WSREP.append(item)


def ask(msg):
    """ Ask user confirmation """
    while True:
        print(msg)
        go_ahead = input('Would you like to continue? (yY/nN) > ')
        if go_ahead.lower() != 'y' and go_ahead.lower() != 'n':
            print('you need to answer either y/Y/n/N\n')
        else:
            break
    if go_ahead.lower() == 'n':
        print('')
        os.sys.exit()


def reverse_lookup(ip_address):
    """ try reverse lookup or return IP """
    try:
        resolved_hostname = socket.gethostbyaddr(ip_address)[0]
    except socket.herror:
        resolved_hostname = "{} [could not resolve IP to hostname]".format(ip_address)

    return resolved_hostname


def kill_mysql():
    """kill mysql"""
    print("\nKilling any running instance of MySQL ...")
    try:
        pysystemd.services('mysql.service').stop()
    except pysystemd.subprocess.CalledProcessError:
        pass
    try:
        pysystemd.services('mysql@bootstrap.service').stop()
    except pysystemd.subprocess.CalledProcessError:
        pass

    mysqlproc = subprocess.Popen(
        ['pgrep', '-f', 'mysqld'],
        stdout=subprocess.PIPE)
    out, _ = mysqlproc.communicate()
    for pid in out.splitlines():
        os.kill(int(pid), signal.SIGKILL)
    if os.path.isfile("/var/lock/subsys/mysql"):
        os.unlink("/var/lock/subsys/mysql")


def restore_mycnf():
    """restore /root/.my.cnf"""
    if os.path.isfile("/root/.my.cnf.bak"):
        os.rename("/root/.my.cnf.bak", "/root/.my.cnf")


def check_install():
    """check if Percona is installed"""
    if distro.os_release_info()['id'] not in ['fedora', 'redhat', 'centos']:
        print("{} is not supported".format(distro.os_release_info()['id']))
        os.sys.exit(1)
    print("\ndetected {} ...".format(distro.os_release_info()['pretty_name']))
    import rpm
    percona_installed = None
    pkg = 'Percona-XtraDB-Cluster-server-{}'.format(PERCONA_MAJOR_VERSION)
    rpmts = rpm.TransactionSet()
    rpmmi = rpmts.dbMatch()
    for pkg_set in rpmmi:
        if pkg_set['name'].decode() == pkg:
            percona_installed = "{}-{}-{}".format(
                pkg_set['name'].decode(),
                pkg_set['version'].decode(),
                pkg_set['release'].decode())

    if percona_installed:
        print('detected {} ...'.format(percona_installed))
    else:
        print("{}{} not installed{}".format(RED, pkg, WHITE))
        os.sys.exit(1)

    return 'percona'


def clean_dir(clean_directory):
    """ purge files under directory """
    item_list = glob.glob(os.path.join(clean_directory, '*'))
    for fileitem in item_list:
        if os.path.isdir(fileitem):
            shutil.rmtree(fileitem)
        else:
            os.unlink(fileitem)


def initialize_mysql(datadirectory):
    """initialize mysql default schemas"""
    fnull = open(os.devnull, 'wb')
    clean_dir(datadirectory)
    initialize = subprocess.Popen([
        '/usr/sbin/mysqld',
        '--initialize-insecure',
        '--datadir={}'.format(datadirectory),
        '--user=mysql'], stdout=fnull)
    _, __ = initialize.communicate()
    retcode = initialize.poll()
    fnull.close()
    if retcode != 0:
        print("Error initializing DB")
        os.sys.exit(1)
    fnull.close()


def check_leader(leader=None):
    """check if this node is the leader"""
    grastate_dat = '/var/lib/mysql/grastate.dat'
    grastate = open(grastate_dat)
    for line in grastate.readlines():
        if 'safe_to_bootstrap' in line and '1' in line:
            leader = True
    if not leader:
        print('It may not be safe to bootstrap the cluster from this node.')
        print('It was not the last one to leave the cluster and may not' \
            ' contain all the updates.')
        print('To force cluster bootstrap with this node, edit the ' \
            '{} file manually and set safe_to_bootstrap to 1'.format(
                grastate_dat))

        os.sys.exit(1)


def bootstrap_mysql(boot):
    """bootstrap the cluster"""
    fnull = open(os.devnull, 'wb')
    kill_mysql()
    if boot == "new":
        if os.path.isfile('/root/.my.cnf'):
            os.rename('/root/.my.cnf', '/root/.my.cnf.bak')
    else:
        check_leader()

    try:
        pysystemd.services('mysql@bootstrap.service').start()
    except pysystemd.subprocess.CalledProcessError as err:
        print("Error bootstrapping the cluster: {}".format(err))
        os.sys.exit(1)
    print('\nsuccessfully bootstrapped the cluster\n')
    if boot == "new":
        bootstrap = subprocess.Popen([
            "/usr/bin/mysqladmin",
            "--no-defaults",
            "--socket=/var/lib/mysql/mysql.sock",
            "-u", "root",
            "password",
            CREDENTIALS["root"]
        ], stdout=fnull)
        _, __ = bootstrap.communicate()
        retcode = bootstrap.poll()
        fnull.close()
        if retcode != 0:
            print("Error setting root password")
        restore_mycnf()


def checkhost(sqlhost, ipv6):
    """check the socket on the other nodes"""
    sqlhostname = reverse_lookup(sqlhost)
    print("\nChecking socket on {} ...".format(sqlhostname))
    if ipv6:
        mping = MultiPing([sqlhost])
    else:
        mping = MultiPing(sqlhost)
    mping.send()
    _, no_responses = mping.receive(1)

    if no_responses:
        print("{}Skipping {}: ping failed{}".format(RED, sqlhostname, WHITE))
        OTHER_WSREP.remove(sqlhost)
    else:
        cnx_sqlhost = None
        try:
            cnx_sqlhost = MySQLdb.connect(
                user='sstuser',
                passwd=CREDENTIALS["sstuser"],
                unix_socket='/var/lib/mysql/mysql.sock',
                host=sqlhost)
        except Exception:
            print("{}Skipping {}: socket is down{}".format(
                YELLOW, sqlhostname, WHITE))
            OTHER_WSREP.remove(sqlhost)
        else:
            print("{}Socket on {} is up{}".format(GREEN, sqlhostname, WHITE))
        finally:
            if cnx_sqlhost:
                cnx_sqlhost.close()


def checkwsrep(sqlhost, ipv6):
    """check if the other nodes belong to the cluster"""
    sqlhostname = reverse_lookup(sqlhost)
    if ipv6:
        mping = MultiPing([sqlhost])
    else:
        mping = MultiPing(sqlhost)
    mping.send()
    _, no_responses = mping.receive(1)
    if no_responses:
        print("{}Skipping {}: it is not in the cluster{}".format(YELLOW, sqlhost, WHITE))
    else:
        print("\nChecking if {} belongs to cluster ...".format(sqlhostname))
        cnx_sqlhost = None
        wsrep_status = 0
        try:
            cnx_sqlhost = MySQLdb.connect(
                user='sstuser',
                passwd=CREDENTIALS["sstuser"],
                unix_socket='/var/lib/mysql/mysql.sock',
                host=sqlhost
            )
            cursor = cnx_sqlhost.cursor()
            wsrep_status = cursor.execute("""show variables LIKE 'wsrep_on'""")
        except Exception:
            pass
        finally:
            if cnx_sqlhost:
                cnx_sqlhost.close()
        if wsrep_status == 1:
            LASTCHECK_NODES.append(sqlhost)
            print("{}{} belongs to cluster{}".format(GREEN, sqlhostname, WHITE))
        else:
            print("{}Skipping {}: it is not in the cluster{}".format(
                YELLOW, sqlhost, WHITE))


def try_joining(how, datadirectory):
    """If we have nodes try Joining the cluster"""
    kill_mysql()
    if how == "new":
        if os.path.isfile('/root/.my.cnf'):
            os.rename('/root/.my.cnf', '/root/.my.cnf.bak')

    if not LASTCHECK_NODES:
        print("{}There are no nodes available in the Cluster{}".format(
            RED, WHITE))
        print("\nEither:")
        print("- None of the hosts has the value 'wsrep_ready' to 'ON'")
        print("- None of the hosts is running the MySQL process\n")
        os.sys.exit(1)
    else:
        try:
            pysystemd.services('mysql.service').start()
        except pysystemd.subprocess.CalledProcessError as err:
            print("{}Unable to gently join the cluster{}:\n{}".format(
                RED, WHITE, err))
            print("Force joining cluster with {}".format(LASTCHECK_NODES[0]))
            if os.path.isfile(os.path.join(datadirectory, "grastate.dat")):
                os.unlink(os.path.join(datadirectory, "grastate.dat"))
                try:
                    pysystemd.services('mysql.service').start()
                except pysystemd.subprocess.CalledProcessError as err:
                    print("{}Unable to join the cluster{}: {}".format(
                        RED, WHITE, err))
                    os.sys.exit(1)
                finally:
                    restore_mycnf()
            else:
                restore_mycnf()
                print("{}Unable to join the cluster{}".format(RED, WHITE))
                os.sys.exit(1)
        else:
            restore_mycnf()
        print('\nsuccessfully joined the cluster\n')


def create_monitor_table():
    """create test table for monitor"""
    print("\nCreating DB test if not exist\n")
    cnx_local_test = MySQLdb.connect(user='root',
                                     passwd=CREDENTIALS["root"],
                                     host='localhost',
                                     unix_socket='/var/lib/mysql/mysql.sock')
    cursor = cnx_local_test.cursor()
    cursor.execute("SET sql_notes = 0;")
    try:
        cursor.execute("""
                    CREATE DATABASE IF NOT EXISTS `test`
                    """)
    except Exception as err:
        print("Could not create database test: {}".format(err))
        os.sys.exit(1)
    else:
        cnx_local_test.commit()
        cnx_local_test.close()

    print("Creating table for Monitor\n")
    cnx_local_test = MySQLdb.connect(user='root',
                                     passwd=CREDENTIALS["root"],
                                     host='localhost',
                                     unix_socket='/var/lib/mysql/mysql.sock',
                                     db='test')
    cursor = cnx_local_test.cursor()

    try:
        cursor.execute("""
                    CREATE TABLE IF NOT EXISTS `monitor` (
                        `id` varchar(255) DEFAULT NULL
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
                    """)
        cnx_local_test.commit()
    except Exception as err:
        print("Could not create test table: {}".format(err))
        os.sys.exit(1)
    else:
        cnx_local_test.commit()

    try:
        cursor.execute("""
                    INSERT INTO test.monitor SET id=("placeholder");
                    """)
        cnx_local_test.commit()
    except Exception as err:
        print("Unable to write to test table: {}".format(err))
    finally:
        if cnx_local_test:
            cnx_local_test.close()


def drop_anonymous():
    """drop anonymous user"""
    all_localhosts = [
        "localhost", "127.0.0.1", "::1",
        MYIP
    ]
    cnx_local = MySQLdb.connect(
        user='root',
        passwd=CREDENTIALS["root"],
        unix_socket='/var/lib/mysql/mysql.sock',
        host='localhost')
    cursor = cnx_local.cursor()
    for onthishost in all_localhosts:
        try:
            cursor.execute("""DROP USER ''@'{}'""".format(onthishost))
        except Exception:
            pass
    if cnx_local:
        cursor.execute("""FLUSH PRIVILEGES""")
        cnx_local.close()


def create_users(thisuser):
    """create users root, monitor and sst and delete anonymous"""
    cnx_local = MySQLdb.connect(user='root',
                                passwd=CREDENTIALS["root"],
                                unix_socket='/var/lib/mysql/mysql.sock',
                                host='localhost')
    cursor = cnx_local.cursor()
    print("Creating user: {}".format(thisuser))
    if thisuser == 'sstuser':
        thisgrant = 'PROCESS, SELECT, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.*'
    elif thisuser == 'monitor':
        thisgrant = 'UPDATE ON test.monitor'

    if thisuser == "root":
        for onthishost in ["localhost", "127.0.0.1", "::1"]:
            try:
                cursor.execute("""
                    CREATE USER IF NOT EXISTS '{}'@'{}' IDENTIFIED BY '{}'
                    """.format(thisuser, onthishost, CREDENTIALS[thisuser]))
            except Exception as err:
                print("Unable to create user {} on {}: {}".format(
                    thisuser,
                    onthishost,
                    err))
            try:
                cursor.execute("""
                    GRANT ALL PRIVILEGES ON *.* TO '{}'@'{}' WITH GRANT OPTION
                    """.format(thisuser, onthishost))
            except Exception as err:
                print("Unable to set permission for {} at {}: {}".format(
                    thisuser,
                    onthishost,
                    err))
                os.sys.exit()
            try:
                cursor.execute("""
                    set PASSWORD for '{}'@'{}' = '{}'
                    """.format(thisuser, onthishost, CREDENTIALS[thisuser]))
            except Exception as err:
                print("Unable to set password for {} on {}: {}".format(
                    thisuser,
                    onthishost,
                    err))
                os.sys.exit()
    else:
        for thishost in GALERA_NODES:
            try:
                cursor.execute("""
                    CREATE USER '{}'@'{}' IDENTIFIED BY '{}'
                    """.format(thisuser, thishost, CREDENTIALS[thisuser]))
            except Exception:
                print("Unable to create user {} on {}".format(
                    thisuser,
                    thishost))
            try:
                cursor.execute("""
                        GRANT {} TO '{}'@'{}'
                        """.format(thisgrant, thisuser, thishost))
            except Exception as err:
                print("Unable to set permission for {} at {}: {}".format(
                    thisuser, thishost, err))
    if cnx_local:
        cursor.execute("""FLUSH PRIVILEGES""")
        cnx_local.close()


class Cluster:
    """ This class will either:
      - create a new cluster on a server
      - create an existing cluster on a server
      - join a new cluster on a server
      - join an existing cluster on a server
      - check cluster status
      - show SQL statements
    """

    def __init__(self, manner, mode, ipv6, datadir='/var/lib/mysql'):
        self.manner = manner
        self.mode = mode
        self.ipv6 = ipv6
        self.datadir = datadir
        self.force = FORCE
        os.chown(self.datadir, pwd.getpwnam("mysql").pw_uid,
                 grp.getgrnam("mysql").gr_gid)

    def createcluster(self):
        """create and bootstrap a cluster"""
        for hostitem in OTHER_NODES:
            checkhost(hostitem, self.ipv6)
        if OTHER_WSREP:
            for wsrepitem in OTHER_WSREP:
                REMAINING_NODES.append(wsrepitem)
        if REMAINING_NODES:
            alive = str(REMAINING_NODES)[1:-1]
            print("{}\nThe following nodes are alive in cluster:{}\n  {}".format(
                RED, WHITE, alive))
            print("\n\nTo boostrap a new cluster you need to switch them off\n")
            os.sys.exit(1)
        else:
            if self.mode == "new" and not self.force:
                ask('\nThis operation will destroy the local data')
                clean_dir(self.datadir)
                initialize_mysql(self.datadir)
            bootstrap_mysql(self.mode)
            if self.mode == "new":
                create_monitor_table()
                GALERA_NODES.append("localhost")
                for creditem in CREDENTIALS:
                    create_users(creditem)
                print("")
                drop_anonymous()

    def joincluster(self):
        """join a cluster"""
        for hostitem in OTHER_NODES:
            checkhost(hostitem, self.ipv6)
        if OTHER_WSREP:
            for wsrepitem in OTHER_WSREP:
                REMAINING_NODES.append(wsrepitem)
        if REMAINING_NODES:
            for wsrephost in OTHER_WSREP:
                checkwsrep(wsrephost, self.ipv6)
        if LASTCHECK_NODES:
            if self.mode == "new" and not self.force:
                ask('\nThis operation will destroy the local data')
                print("\ninitializing mysql tables ...")
                initialize_mysql(self.datadir)
            elif self.mode == "new" and self.force:
                print("\ninitializing mysql tables ...")
                initialize_mysql(self.datadir)
        try_joining(self.manner, self.datadir)

    def checkonly(self):
        """runs a cluster check"""
        OTHER_WSREP.append(MYIP)
        for hostitem in GALERA_NODES:
            checkhost(hostitem, self.ipv6)
        if OTHER_WSREP:
            for wsrepitem in OTHER_WSREP:
                REMAINING_NODES.append(wsrepitem)
        if REMAINING_NODES:
            for wsrephost in OTHER_WSREP:
                checkwsrep(wsrephost, self.ipv6)
        print('')

    def show_statements(self):
        """Show SQL statements to create all stuff"""
        os.system('clear')
        GALERA_NODES.append("localhost")
        print("\n# remove anonymous user\nDROP USER ''@'localhost'")
        print("DROP USER ''@'{}'".format(MYIP))
        print("\n# create monitor table\nCREATE DATABASE IF NOT EXIST `test`;")
        print("CREATE TABLE IF NOT EXISTS `test`.`monitor` ( `id` varchar(255) DEFAULT NULL ) " \
              "ENGINE=InnoDB DEFAULT CHARSET=utf8;")
        print('INSERT INTO test.monitor SET id=("placeholder");')
        for thisuser in ['root', 'sstuser', 'monitor']:
            print("\n# define user {}".format(thisuser))
            if thisuser == "root":
                for onthishost in ["localhost", "127.0.0.1", "::1"]:
                    print("set PASSWORD for 'root'@'{}' = '{}'".format(
                        onthishost, CREDENTIALS[thisuser]))
            for thishost in GALERA_NODES:
                if thisuser != "root":
                    print("CREATE USER \'{}\'@\'{}\' IDENTIFIED BY \'{}\';".format(
                        thisuser, thishost, CREDENTIALS[thisuser]))
            for thishost in GALERA_NODES:
                if thisuser == "sstuser":
                    thisgrant = "PROCESS, SELECT, RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.*"
                elif thisuser == "monitor":
                    thisgrant = "UPDATE ON test.monitor"
                if thisuser != "root":
                    print("GRANT {} TO '{}'@'{}';".format(
                        thisgrant, thisuser, thishost))
        print("")


def parse(ipv6):
    """Parse options thru argparse and run it..."""
    intro = """\
         Use this script to bootstrap, join nodes within a Galera Cluster
         ----------------------------------------------------------------
           Avoid joining more than one node at once!
         """
    parser = argparse.ArgumentParser(
        formatter_class=lambda prog:
        argparse.RawDescriptionHelpFormatter(prog, max_help_position=29),
        description=textwrap.dedent(intro),
        epilog="Author: Massimiliano Adamo <maxadamo@gmail.com>")
    parser.add_argument(
        '-cg', '--check-galera', help='check if nodes are healthy', action='store_true',
        dest='Cluster(None, None, {}).checkonly()'.format(ipv6), required=False)
    parser.add_argument(
        '-dr', '--dry-run', help='print SQL statements', action='store_true',
        dest='Cluster(None, None, {}).show_statements()'.format(ipv6), required=False)
    parser.add_argument(
        '-je', '--join-existing', help='join existing Cluster', action='store_true',
        dest='Cluster("existing", "existing", {}).joincluster()'.format(ipv6), required=False)
    parser.add_argument(
        '-be', '--bootstrap-existing', help='bootstrap existing Cluster', action='store_true',
        dest='Cluster(None, "existing", {}).createcluster()'.format(ipv6), required=False)
    parser.add_argument(
        '-jn', '--join-new', help='join new Cluster', action='store_true',
        dest='Cluster("new", "new", {}).joincluster()'.format(ipv6), required=False)
    parser.add_argument(
        '-bn', '--bootstrap-new', action='store_true', help='bootstrap new Cluster',
        dest='Cluster(None, "new", {}).createcluster()'.format(ipv6), required=False)
    parser.add_argument('-f', '--force', action='store_true',
                        help='force bootstrap-new or join-new Cluster', required=False)

    return parser.parse_args()


# Here we Go.
if __name__ == "__main__":
    filterwarnings('ignore', category=MySQLdb.Warning)
    try:
        _ = pwd.getpwnam("mysql").pw_uid
    except KeyError:
        print("Could not find the user mysql\nGiving up...")
        os.sys.exit(1)
    try:
        _ = grp.getgrnam("mysql").gr_gid
    except KeyError:
        print("Could not find the group mysql\nGiving up...")
        os.sys.exit(1)

    IPV6 = None
    try:
        ipaddress.IPv4Address(MYIP)
    except ipaddress.AddressValueError:
        try:
            ipaddress.IPv6Address(MYIP)
        except ipaddress.AddressValueError:
            print("Neither IPv6 nor IPv4 were detected\nGiving up...")
            os.sys.exit()
        else:
            IPV6 = True

    ARGS = parse(IPV6)
    ARGSDICT = vars(ARGS)
    if ARGS.force:
        FORCE = True

    check_install()

    if not any(ARGSDICT.values()):
        print('\n\tNo arguments provided.\n\tUse -h, --help for help')
    else:
        for key in list(ARGSDICT.keys()):
            if ARGSDICT[str(key)] is True:
                if key != 'force':
                    eval(key)
