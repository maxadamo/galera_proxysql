require 'spec_helper_acceptance'
describe 'galera_proxysql class:', if: ENV['HOST_TYPE'] == 'galera' do
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
          baseurl => 'http://repo.percona.com/pxc-57/yum/release/$releasever/RPMS/$basearch',
          descr   => 'Percona-PXC57';
        'percona-pxb':
          baseurl => 'http://repo.percona.com/pxb-24/yum/release/$releasever/RPMS/$basearch',
          descr   => 'Percona-ExtraBackup';
        'percona-pt':
          baseurl => 'http://repo.percona.com/pt/yum/release/$releasever/RPMS/$basearch',
          descr   => 'Percona-Toolkit';
        'percona-prel':
          baseurl => 'http://repo.percona.com/prel/yum/release/$releasever/RPMS/noarch',
          descr   => 'Percona-Release';
      }
      -> exec { 'yum check-update || true':
        require => Class['epel'],
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
        -> class { 'galera_proxysql':
          root_password    => $root_password,
          sst_password     => $sst_password,
          monitor_password => $monitor_password,
          galera_hosts     => $galera_hosts,
          proxysql_hosts   => $proxysql_hosts,
          proxysql_vip     => $proxysql_vip,
          manage_repo      => true,
          manage_lvm       => false;
        }
      EOS

      # Run it twice and test for idempotency
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_failures: true)
      apply_manifest(pp, hiera_config: '/etc/puppetlabs/code/environments/production/modules/galera_proxysql/hiera.yaml', catch_changes: true)
    end
  end
  # context 'CentOS_6' do
  #   let(:facts) do
  #     {
  #       'osfamily' => 'RedHat',
  #       'operatingsystem' => 'CentOS',
  #       'architecture' => 'x86_64',
  #       'lsbdistcodename' => 'Final',
  #       'virtual' => 'hyperv',
  #       'operatingsystemmajrelease' => '6',
  #       'operatingsystemrelease' => '6.9',
  #       'lsbmajdistrelease' => '6',
  #       'os' => {
  #         'name' => 'CentOS',
  #         'release' => {
  #           'major' => '6',
  #           'full' => '6.9',
  #         },
  #       },
  #     }
  #   end

  #   it {
  #     is_expected.to contain_class('galera_proxysql')
  #   }
  # end
end
