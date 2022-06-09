# Cookbook:: gitlab-patroni
# Spec:: snapshot
#
# Copyright:: 2020, GitLab B.V., MIT.

require 'spec_helper'
require 'chef-vault/test_fixtures'

describe 'gitlab-patroni::zlonk' do
  include ChefVault::TestFixtures.rspec_shared_context

  let(:chef_run) do
    ChefSpec::ServerRunner.new do |node|
      node.normal['gitlab-patroni']['zlonk']['project'] = 'project'
      node.normal['gitlab-patroni']['zlonk']['instance'] = 'instance'
    end.converge(described_recipe)
  end

  it 'creates a directory for zlonk' do
    expect(chef_run).to create_directory('/var/opt/gitlab/postgresql/opt/zlonk').with(recursive: true)
  end

  it 'syncs zlonk git' do
    expect(chef_run).to sync_git('/var/opt/gitlab/postgresql/opt/zlonk')
  end

  it 'creates log directory' do
    expect(chef_run).to create_directory('/var/log/gitlab/zlonk/project/instance')
  end

  context 'with zlonk enabled' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new do |node|
        node.normal['gitlab-patroni']['zlonk']['enabled'] = true
        node.normal['gitlab-patroni']['zlonk']['project'] = 'project'
        node.normal['gitlab-patroni']['zlonk']['instance'] = 'instance'  
      end.converge(described_recipe)
    end
    it 'creates cron for snapshots' do
      expect(chef_run).to create_cron('zlonk create').with(
        command: '/var/opt/gitlab/postgresql/opt/zlonk/bin/zlonk.sh project instance >> /var/log/gitlab/zlonk/project/instance/zlonk.log 2>&1',
        hour: '21',
        minute: '45'
      )
      expect(chef_run).to create_cron('zlonk destroy').with(
        command: '/var/opt/gitlab/postgresql/opt/zlonk/bin/zlonk.sh project instance >> /var/log/gitlab/zlonk/project/instance/zlonk.log 2>&1',
        hour: '21',
        minute: '30'
      ) 
    end
  end
  context 'with zlonk disabled' do
    let(:chef_run) do
      ChefSpec::ServerRunner.new do |node|
        node.normal['gitlab-patroni']['zlonk']['enabled'] = false
        node.normal['gitlab-patroni']['zlonk']['project'] = 'project'
        node.normal['gitlab-patroni']['zlonk']['instance'] = 'instance'  
      end.converge(described_recipe)
    end
    it 'creates cron for snapshots' do
      expect(chef_run).to_not create_cron('zlonk create').with(
        command: '/var/opt/gitlab/postgresql/opt/zlonk/bin/zlonk.sh project instance >> /var/log/gitlab/zlonk/project/instance/zlonk.log 2>&1',
        hour: '21',
        minute: '45'
      )
      expect(chef_run).to_not create_cron('zlonk destroy').with(
        command: '/var/opt/gitlab/postgresql/opt/zlonk/bin/zlonk.sh project instance >> /var/log/gitlab/zlonk/project/instance/zlonk.log 2>&1',
        hour: '21',
        minute: '30'
      ) 
    end
  end
end

