require 'spec_helper'
describe 'galera_maxscale' do
  context 'with default values for all parameters' do
    it { should contain_class('galera_maxscale') }
  end
end
