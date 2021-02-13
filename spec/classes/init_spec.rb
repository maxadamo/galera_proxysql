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

    it {
      is_expected.to contain_class('galera_proxysql')
    }
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
