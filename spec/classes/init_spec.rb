require 'spec_helper'
describe 'galera_proxysql' do
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

    it 'works idempotently with no errors' do
      pp = <<-EOS
        class { 'galera_proxysql':
          root_password    => Sensitive('root'),
          sst_password     => Sensitive('sst'),
          monitor_password => Sensitive('monitor'),
          force_ipv6       => false,
          galera_hosts     =>  {
            'test-galera01.geant.net' => {'ipv4'=>'192.168.1.50'},
            'test-galera02.geant.net' => {'ipv4'=>'192.168.1.51'},
            'test-galera03.geant.net' => {'ipv4'=>'192.168.1.52'}
          },
          proxysql_hosts   => ['192.168.1.101'],
          proxysql_vip     => '192.168.1.100',
          manage_repo      => true,
          manage_lvm       => false;
        }
      EOS
  end
  context 'CentOS_6' do
    let(:facts) do
      {
        'osfamily' => 'RedHat',
        'operatingsystem' => 'CentOS',
        'architecture' => 'x86_64',
        'lsbdistcodename' => 'Final',
        'virtual' => 'hyperv',
        'operatingsystemmajrelease' => '6',
        'operatingsystemrelease' => '6.9',
        'lsbmajdistrelease' => '6',
        'os' => {
          'name' => 'CentOS',
          'release' => {
            'major' => '6',
            'full' => '6.9',
          },
        },
      }
    end

    it {
      is_expected.to contain_class('galera_proxysql')
    }
  end
end
