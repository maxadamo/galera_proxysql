require 'spec_helper_acceptance'
describe 'galera_proxysql class:', if: ENV['HOST_TYPE'] == 'proxysql' && ENV['MAJOR'] == '80' do
  before(:all) do
    # due to class containment issue yumrepo might not be executed in advance
    preamble = <<-MANIFEST
      rpmkey { '8507EFA5':
        ensure => present,
        source => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY';
      }
      -> yumrepo { 'percona-pdpxc80':
        enabled    => '1',
        gpgcheck   => '1',
        proxy      => $http_proxy,
        mirrorlist => absent,
        gpgkey     => 'https://repo.percona.com/percona/yum/PERCONA-PACKAGING-KEY',
        require    => Rpmkey['8507EFA5'],
        baseurl    => 'https://repo.percona.com/pdpxc-8.0/yum/release/$releasever/RPMS/$basearch/',
        descr      => 'Percona-PDPXC80';
      }
      -> exec { 'yum check-update || true':
        path => '/usr/bin:/usr/sbin';
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
      pp = <<-EOS
        $galera_hosts = lookup('galera_proxysql::galera_hosts')
        $proxysql_hosts = lookup('galera_proxysql::proxysql_hosts')
        $proxysql_vip = lookup('galera_proxysql::proxysql_vip')
        $trusted_networks = lookup('galera_proxysql::trusted_networks')
        $monitor_password = Sensitive(lookup('galera_proxysql::monitor_password'))

        class { 'firewall': ensure_v6 => stopped; }
        -> class { 'galera_proxysql::proxysql::proxysql':
          percona_major_version => '80',
          manage_ssl            => false,
          manage_firewall       => true,
          proxysql_port         => 3310,
          trusted_networks      => $trusted_networks,
          monitor_password      => $monitor_password,
          proxysql_hosts        => $proxysql_hosts,
          proxysql_vip          => $proxysql_vip,
          galera_hosts          => $galera_hosts,
          manage_repo           => false;
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

      # keepalived keeps flapping inside the container and idempotency will not work
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
    end

    describe file('/etc/proxysql-admin.cnf') do
      it { is_expected.to be_file }
      it { is_expected.to be_mode 640 }
      it { is_expected.to be_owned_by 'proxysql' }
      it { is_expected.to be_grouped_into 'proxysql' }
    end

    describe file('/etc/proxysql.cnf') do
      it { is_expected.to be_file }
      it { is_expected.to be_mode 640 }
      it { is_expected.to be_owned_by 'proxysql' }
      it { is_expected.to be_grouped_into 'proxysql' }
      # rubocop:disable RepeatedDescription
      its(:content) { is_expected.to include 'username = "monitor", password = "monitor_pass"' }
      its(:content) { is_expected.to include 'username = "test_two", password = "test_two_pass",' }
    end

    describe file('/root/.my.cnf') do
      it { is_expected.to be_file }
      it { is_expected.to be_mode 660 }
      it { is_expected.to be_owned_by 'root' }
      it { is_expected.to be_grouped_into 'root' }
      its(:content) { is_expected.to include '[client]' }
      its(:content) { is_expected.to include 'user=monitor' }
      its(:content) { is_expected.to include 'password=monitor_pass' }
      # rubocop:enable RepeatedDescription
    end

    describe service('proxysql') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe service('keepalived') do
      it { is_expected.to be_enabled }
    end

    describe port(3307) do
      it { is_expected.to be_listening.with('tcp') }
    end

    describe port(3310) do
      it { is_expected.to be_listening.with('tcp') }
    end
  end
end
