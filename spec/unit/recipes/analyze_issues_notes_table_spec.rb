# Cookbook:: gitlab-patroni
# Spec:: analyze
#
# Copyright:: 2021, GitLab, Inc., MIT.

require 'spec_helper'
require 'chef-vault/test_fixtures'

describe 'gitlab-patroni::analyze_issues_notes_table' do
  include ChefVault::TestFixtures.rspec_shared_context

  let(:chef_run) do
    ChefSpec::ServerRunner.new do |node|
      node.normal['etc']['passwd'] = {}
      node.normal['gitlab-patroni']['analyze']['analyze_script_path'] = '/usr/local/bin/analyze-issues_notes-table.sh'
      node.normal['gitlab-patroni']['analyze']['log_path_prefix'] = '/var/log/gitlab/postgresql/analyze-issues_notes-table'
    end.converge(described_recipe)
  end

  it 'creates the analyze-issues_notes-table script' do
    path = '/usr/local/bin/analyze-issues_notes-table.sh'

    expect(chef_run).to create_cookbook_file(path).with(owner: 'postgres', group: 'postgres', mode: '0777')
  end

  it 'creates cron to start analyze issues_notes' do
    expect(chef_run).to create_cron('analyze_issues_notes_table').with(
      command: '/usr/local/bin/analyze-issues_notes-table.sh',
      path: '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
    )
  end

  it 'rotates the logs' do
    expect(chef_run).to enable_logrotate_app('analyze_issues_notes_table').with(
      path: '/var/log/gitlab/postgresql/analyze-issues_notes-table*.log',
      options: %w(missingok compress delaycompress notifempty),
      rotate: 7,
      frequency: 'daily'
    )
  end
end
