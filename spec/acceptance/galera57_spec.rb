require 'spec_helper_acceptance'
describe 'galera_proxysql class:', if: ENV['HOST_TYPE'] == 'galera' && ENV['MAJOR'] == '57' do
  before(:all) do
    # due to class containment issue yumrepo might not be executed in advance
    preamble = <<-MANIFEST
      include epel
      rpmkey { '8507EFA5':
        ensure => present,
        source => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY';
      }
      -> yumrepo {
        default:
          enabled    => '1',
          gpgcheck   => '1',
          mirrorlist => absent,
          gpgkey     => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY',
          require    => Rpmkey['8507EFA5'];
        'percona-pxc57':
          baseurl => 'http://repo.percona.com/pxc-57/yum/release/7/RPMS/x86_64/',
          descr   => 'Percona-PXC57';
        'percona-pxb':
          baseurl => 'http://repo.percona.com/pxb-24/yum/release/$releasever/RPMS/$basearch',
          descr   => 'Percona-ExtraBackup';
        'percona-pt':
          baseurl => 'http://repo.percona.com/pt/yum/release/7/RPMS/x86_64/',
          descr   => 'Percona-Toolkit';
      }
      -> exec { 'yum check-update || true':
        provider => shell,
        require  => Class['epel'],
        path     => '/usr/bin:/usr/sbin';
      }
    MANIFEST

    apply_manifest(preamble)
  end

  context 'CentOS_7' do
    let(:facts) do
      {
        'osfamily' => 'RedHat',
        'operatingsystem' => 'CentOS',
        'architecture' => 'x86_64',
        'lsbdistcodename' => 'Core',
        'virtual' => 'hyperv',
        'operatingsystemmajrelease' => '7',
        'operatingsystemrelease' => '7.4.1708',
        'lsbmajdistrelease' => '7',
        'os' => {
          'name' => 'CentOS',
          'release' => {
            'major' => '7',
            'full' => '7.4.1708',
          },
        },
      }
    end

    it 'applies the manifest with no errors' do
      # puppet apply manifest.pp --trace --hiera_config='/etc/puppetlabs/cod.....alera_proxysql/hiera.yaml' --debug --detailed-exitcodes
      pp = <<-EOS
        $galera_hosts = lookup('galera_proxysql::galera_hosts')
        $proxysql_hosts = lookup('galera_proxysql::proxysql_hosts')
        $proxysql_vip = lookup('galera_proxysql::proxysql_vip')
        $trusted_networks = lookup('galera_proxysql::trusted_networks')
        $root_password = Sensitive(lookup('galera_proxysql::root_password'))
        $monitor_password = Sensitive(lookup('galera_proxysql::monitor_password'))

        class { 'firewall': ensure_v6 => stopped; }
        -> class { 'galera_proxysql':
          root_password         => $root_password,
          percona_major_version => '57',
          sst_password          => Sensitive('sst_pass'),
          monitor_password      => $monitor_password,
          galera_hosts          => $galera_hosts,
          proxysql_hosts        => $proxysql_hosts,
          proxysql_vip          => $proxysql_vip,
          proxysql_port         => 3310,
          manage_firewall       => true,
          manage_repo           => true,
          manage_lvm            => false;
        }
        -> galera_proxysql::create::user {
          default:
            galera_hosts   => $galera_hosts,
            proxysql_hosts => $proxysql_hosts,
            proxysql_vip   => $proxysql_vip,
            privileges     => ['ALL'];
          'test_one':
            dbpass => Sensitive('test_one_pass'),
            table  => 'test_one.*';
          'test_two':
            dbpass => Sensitive('test_two_pass'),
            table  => 'test_two.*';
        }
      EOS
      # we are not checking idemptency but we run it 3 times
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
      # apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_changes: true)
    end

    describe file('/root/.my.cnf') do
      it { is_expected.to be_file }
      it { is_expected.to be_mode 660 }
      it { is_expected.to be_owned_by 'root' }
      it { is_expected.to be_grouped_into 'root' }
      its(:content) { is_expected.to include '[client]' }
      its(:content) { is_expected.to include 'user=root' }
      its(:content) { is_expected.to include 'password=66' }
    end

    describe service('xinetd') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe service('mysql@bootstrap') do
      it { is_expected.to be_running }
    end

    describe service('iptables') do
      it { is_expected.to be_running }
    end

    describe file('/etc/services') do
      its(:content) { is_expected.to include 'galerachk' }
    end

    describe command('mysql --defaults-file=/root/.my.cnf -NBe \'select user,host from mysql.user WHERE `user` = "test_one" AND `host` = "localhost"\' | grep -w test_one') do
      its(:stdout) { is_expected.to include 'test_one' }
    end

    describe command('mysql --defaults-file=/root/.my.cnf -NBe \'SHOW STATUS LIKE "wsrep_ready"\' | grep -w ON') do
      its(:stdout) { is_expected.to include 'ON' }
    end

    describe command('/usr/bin/clustercheck') do
      its(:stdout) { is_expected.to include 'Cluster Node is synced' }
    end

  end
end
