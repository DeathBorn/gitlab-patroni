# Cookbook:: gitlab-patroni
# Spec:: reset sampling
#
# Copyright:: 2021, GitLab, Inc., MIT.

require 'spec_helper'
require 'chef-vault/test_fixtures'

describe 'gitlab-patroni::reset_sampling' do
  include ChefVault::TestFixtures.rspec_shared_context

  let(:chef_run) do
    ChefSpec::ServerRunner.new do |node|
      node.normal['etc']['passwd'] = {}
      node.normal['gitlab-patroni']['reset_sampling']['reset_sampling_script_path'] = '/usr/local/bin/reset_sampling.sh'
      node.normal['gitlab-patroni']['reset_sampling']['log_path_prefix'] = '/var/log/gitlab/postgresql/reset_sampling'
    end.converge(described_recipe)
  end

  it 'creates the reset_sampling script' do
    path = '/usr/local/bin/reset_sampling.sh'

    expect(chef_run).to create_cookbook_file(path).with(owner: 'postgres', group: 'postgres', mode: '0777')
  end

  it 'creates cron to start reset_sampling' do
    expect(chef_run).to create_cron('reset_sampling').with(
      command: '/usr/local/bin/reset_sampling.sh',
      path: '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
    )
  end

  it 'rotates the logs' do
    expect(chef_run).to enable_logrotate_app('reset_sampling').with(
      path: '/var/log/gitlab/postgresql/reset_sampling*.log',
      options: %w(missingok compress delaycompress notifempty),
      rotate: 7,
      frequency: 'daily'
    )
  end
end
