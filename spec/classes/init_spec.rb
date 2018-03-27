require 'spec_helper'
describe 'galera_proxysql' do
  context 'with default values for all parameters' do
    it { should contain_class('galera_proxysql') }
  end
end
