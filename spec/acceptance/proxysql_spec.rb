require 'spec_helper_acceptance'
describe 'galera_proxysql class:', if: ENV['HOST_TYPE'] == 'proxysql' do
  before(:all) do
    # due to class containment issue yumrepo might not be executed in advance
    preamble = <<-MANIFEST
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
        'proxysql':
          baseurl => 'http://repo.percona.com/proxysql/yum/release/$releasever/RPMS/$basearch',
          descr   => 'ProxySQL';
        'percona-percona':
          baseurl => 'http://repo.percona.com/percona/yum/release/$releasever/RPMS/$basearch',
          descr   => 'Percona';
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
        $root_password = Sensitive(lookup('galera_proxysql::root_password'))
        $sst_password = Sensitive(lookup('galera_proxysql::sst_password'))
        $monitor_password = Sensitive(lookup('galera_proxysql::monitor_password'))

        class { 'firewall': ensure_v6 => stopped; }
        -> class { 'galera_proxysql::proxysql::proxysql':
          manage_ssl                 => false,
          manage_firewall            => true,
          proxysql_port              => 3310,
          trusted_networks           => $trusted_networks,
          monitor_password           => $monitor_password,
          proxysql_hosts             => $proxysql_hosts,
          proxysql_vip               => $proxysql_vip,
          galera_hosts               => $galera_hosts,
          manage_repo                => false;
        }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
      # keepalived keeps flapping and it doesn't work idempotently
      # apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_changes: true)
    end
  end
end
