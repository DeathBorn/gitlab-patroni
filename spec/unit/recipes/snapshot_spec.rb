# Cookbook:: gitlab-patroni
# Spec:: snapshot
#
# Copyright:: 2020, GitLab B.V., MIT.

require 'spec_helper'
require 'chef-vault/test_fixtures'

describe 'gitlab-patroni::snapshot' do
  include ChefVault::TestFixtures.rspec_shared_context

  let(:chef_run) do
    ChefSpec::ServerRunner.new do |node|
      node.normal['etc']['passwd'] = {}
      node.normal['gitlab-patroni']['snapshot']['gcs_credentials'] = 'aHVudGVyMQo='
      node.normal['gce']['project']['projectId'] = 'gitlab-rspec'
      node.normal['gce']['instance']['zone'] = 'project/123/zone/us-east-66c'
      node.normal['gce']['instance']['name'] = 'patroni-rspec-06'

      node.normal['prometheus']['labels'] = {
        'shard' => 'main',
        'tier' => 'db',
        'type' => 'patroni'
      }
    end.converge(described_recipe)
  end

  it 'creates a directory to store credentials in' do
    expect(chef_run).to create_directory('/etc/gitlab').with(recursive: true)
  end

  it 'creates the credentials file' do
    path = '/etc/gitlab/gcs-snapshot.json'

    expect(chef_run).to create_file(path).with(mode: '0600', sensitive: true, owner: 'postgres')
    expect(chef_run).to render_file(path).with_content('hunter1')
  end

  it 'creates the snapshot script' do
    path = '/usr/local/bin/gcs-snapshot.sh'

    expect(chef_run).to create_template(path).with(mode: '0777')
    expect(chef_run).to render_file(path).with_content(File.read('spec/fixtures/gcs-snapshot.sh'))
  end

  it 'creates cron to start pg backup for GCP snapshot' do
    expect(chef_run).to create_cron('GCS snapshot').with(
      command: '/usr/local/bin/gcs-snapshot.sh',
      path: '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin'
    )
  end

  it 'rotates the logs' do
    expect(chef_run).to enable_logrotate_app('gcs_snapshot').with(
      path: '/var/log/gitlab/postgresql/gcs-snapshot*.log',
      options: %w(missingok compress delaycompress notifempty),
      rotate: 7,
      frequency: 'daily'
    )
  end
end
