# Cookbook:: gitlab-patroni
# Spec:: default
#
# Copyright:: 2018, GitLab B.V., MIT.

require 'spec_helper'

describe 'gitlab-patroni::default' do
  context 'when all attributes are default, on Ubuntu 16.04' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new(platform: 'ubuntu',
                                 version: '16.04')
                            .converge(described_recipe)
    end

    it 'converges succesfully' do
      expect { chef_run }.to_not raise_error
    end
  end
end
