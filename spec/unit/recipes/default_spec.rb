# Cookbook:: gitlab-patroni
# Spec:: default
#
# Copyright:: 2018, GitLab B.V., MIT.

require 'spec_helper'
require 'chef-vault/test_fixtures'

describe 'gitlab-patroni::default' do
  include ChefVault::TestFixtures.rspec_shared_context

  let(:chef_run) do
    ChefSpec::ServerRunner.new do |node|
      node.normal['etc']['passwd'] = {}
    end.converge(described_recipe)
  end

  before do
    mock_secrets_path = 'spec/fixtures/secrets.json'
    secrets           = JSON.parse(File.read(mock_secrets_path))

    expect_any_instance_of(Chef::Recipe).to receive(:get_secrets)
      .with('dummy', { 'path' => 'gitlab-gstg-secrets/gitlab-patroni', 'item' => 'gstg.enc' }, 'ring' => 'gitlab-secrets', 'key' => 'gstg', 'location' => 'global')
      .and_return(secrets)

    stub_command('systemctl status patroni').and_return(true)
  end

  describe 'PostgreSQL' do
    it 'creates PostgreSQL config directory' do
      expect(chef_run).to create_directory('/var/opt/gitlab/postgresql').with(owner: 'postgres', group: 'postgres')
    end

    it 'creates postgresql.conf if it is missing' do
      conf_path    = '/var/opt/gitlab/postgresql/postgresql.conf'
      conf_content = File.read('spec/fixtures/postgresql.conf')

      expect(chef_run).to create_if_missing_cookbook_file(conf_path).with(owner: 'postgres', group: 'postgres')
      expect(chef_run).to render_file(conf_path).with_content(conf_content)
    end

    describe 'postgresql.base.conf' do
      let(:conf_path) { '/var/opt/gitlab/postgresql/postgresql.base.conf' }

      context 'when it already exists' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(conf_path).and_return(true)
        end

        it 'updates the file' do
          expect(chef_run).to create_cookbook_file(conf_path)
        end
      end

      context 'when it does not exist' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(conf_path).and_return(false)
        end

        it 'does not create the file' do
          expect(chef_run).not_to render_file(conf_path)
        end
      end
    end

    describe 'PostgreSQL user' do
      context 'when the users exists' do
        let(:chef_run) do
          ChefSpec::ServerRunner.new do |node|
            node.normal['etc']['passwd']['postgres'] = {}
          end.converge(described_recipe)
        end

        it 'does not create the user' do
          expect(chef_run).not_to create_user('postgres')
        end
      end

      context 'when the users does not exist' do
        it 'creates the user' do
          expect(chef_run).to create_user('postgres').with(manage_home: true, home: '/var/opt/gitlab/postgresql')
        end
      end
    end

    it 'stops and disables postgresql service' do
      expect(chef_run).to stop_service('postgresql')
      expect(chef_run).to disable_service('postgresql')
    end

    it 'creates PostgreSQL certificate files' do
      ssl_cacert_content = "GlobalSign Root CA\n==================\n-----BEGIN CERTIFICATE-----\nCA Root Certificates-----END CERTIFICATE-----"
      ssl_cert_content = "-----BEGIN CERTIFICATE-----\nThis is the certificate\n-----END CERTIFICATE-----\n"
      ssl_key_content = "-----BEGIN RSA PRIVATE KEY-----\nThis is the private key-----END RSA PRIVATE KEY-----\n"

      expect(chef_run).to create_file('/var/opt/gitlab/postgresql/cacert.pem').with(
        content: ssl_cacert_content, mode: '0600', owner: 'postgres', group: 'postgres', sensitive: true
      )
      expect(chef_run).to create_file('/var/opt/gitlab/postgresql/server.crt').with(
        content: ssl_cert_content, mode: '0600', owner: 'postgres', group: 'postgres', sensitive: true
      )
      expect(chef_run).to create_file('/var/opt/gitlab/postgresql/server.key').with(
        content: ssl_key_content, mode: '0600', owner: 'postgres', group: 'postgres', sensitive: true
      )
    end
  end

  describe 'Patroni' do
    it 'updates apt' do
      expect(chef_run).to periodic_apt_update('apt update')
    end

    it 'installs Python runtime' do
      expect(chef_run).to install_python_runtime('3').with(pip_version: '18.0')
    end

    it 'creates Patroni virtualenv' do
      expect(chef_run).to create_python_virtualenv('/opt/patroni').with(pip_version: '18.0')
    end

    it 'installs Patroni' do
      expect(chef_run).to install_python_package('patroni[consul]').with(version: '1.5.0')
    end

    it 'creates Patroni config directory' do
      expect(chef_run).to create_directory('/var/opt/gitlab/patroni').with(owner: 'postgres', group: 'postgres')
    end

    it 'creates patroni.yml' do
      config_path    = '/var/opt/gitlab/patroni/patroni.yml'
      patroni_config = File.read('spec/fixtures/patroni.yml')

      expect(chef_run).to create_file(config_path).with(owner: 'postgres', group: 'postgres', content: patroni_config)
      expect(chef_run.file(config_path)).to notify('poise_service[patroni]').to(:reload).delayed
    end

    describe 'updating bootstrap config' do
      context 'patroni service is not running' do
        before do
          stub_command('systemctl status patroni').and_return(false)
        end

        it 'does not update the config' do
          expect(chef_run).not_to run_execute('update bootstrap config')
        end
      end

      context 'patroni service is running' do
        it 'updates the config' do
          command = <<-CMD
/opt/patroni/bin/patronictl -c /var/opt/gitlab/patroni/patroni.yml edit-config --replace - <<-YML
---
ttl: 30
loop_wait: 10
retry_timeout: 10
maximum_lag_on_failover: 1048576
postgresql:
  use_pg_rewind: true
  use_slots: true
  parameters:
    wal_level: replica
    hot_standby: 'on'
    wal_keep_segments: 8
    max_wal_senders: 5
    max_replication_slots: 5
    checkpoint_timeout: 30

YML
          CMD

          expect(chef_run).to run_execute('update bootstrap config').with(command: command)
        end
      end
    end

    it 'creates Patroni log directory' do
      expect(chef_run).to create_directory('/var/log/gitlab/patroni').with(owner: 'syslog', group: 'syslog')
    end

    it 'creates PostgreSQL log directory' do
      expect(chef_run).to create_directory('/var/log/gitlab/postgresql').with(owner: 'syslog', group: 'syslog')
    end

    it 'creates Patroni rsyslog config' do
      config_path = '/etc/rsyslog.d/50-patroni.conf'

      expect(chef_run).to render_file(config_path).with_content(start_with("if $programname == 'patroni' then /var/log/gitlab/patroni/patroni.log"))
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end

    it 'creates PostgreSQL rsyslog config' do
      config_path = '/etc/rsyslog.d/51-postgresql.conf'

      expect(chef_run).to render_file(config_path).with_content(start_with("if $programname == 'postgres' then /var/log/gitlab/postgresql/postgres.log"))
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end
  end
end
