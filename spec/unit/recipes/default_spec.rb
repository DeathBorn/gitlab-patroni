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
      node.normal['gitlab-patroni']['patroni']['custom_scripts'] = true
    end.converge(described_recipe)
  end
  let(:guard_command) { 'systemctl status patroni && /usr/local/bin/gitlab-patronictl list | grep chefspec | grep running' }

  before do
    mock_secrets_path = 'spec/fixtures/secrets.json'
    secrets           = JSON.parse(File.read(mock_secrets_path))

    expect_any_instance_of(Chef::Recipe).to receive(:get_secrets)
      .with('dummy', { 'path' => 'gitlab-gstg-secrets/gitlab-patroni', 'item' => 'gstg.enc' }, 'ring' => 'gitlab-secrets', 'key' => 'gstg', 'location' => 'global')
      .and_return(secrets)

    stub_command(guard_command).and_return(true)
  end

  describe 'PostgreSQL' do
    it 'creates PostgreSQL config directory' do
      expect(chef_run).to create_directory('/var/opt/gitlab/postgresql').with(owner: 'postgres', group: 'postgres')
    end

    it 'installs apt-transport-https' do
      expect(chef_run).to install_package('apt-transport-https')
    end

    it 'adds PostgreSQL APT repository' do
      expect(chef_run).to add_apt_repository('postgresql').with(
        uri: 'https://download.postgresql.org/pub/repos/apt/',
        components: ['main', '9.6'],
        distribution: 'xenial-pgdg',
        key: ['https://download.postgresql.org/pub/repos/apt/ACCC4CF8.asc'],
        cache_rebuild: true
      )
    end

    it 'installs postgresql' do
      expect(chef_run).to install_package('postgresql-9.6')
    end

    it 'installs pg_repack extension' do
      expect(chef_run).to install_package('postgresql-9.6-repack')
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

    it 'sets shmmax kernel parameter' do
      expect(chef_run).to apply_sysctl_param('kernel.shmmax').with(value: '123480309760')
    end

    it 'sets shmall kernel parameter' do
      expect(chef_run).to apply_sysctl_param('kernel.shmall').with(value: '30146560')
    end

    it 'sets sem kernel parameter' do
      expect(chef_run).to apply_sysctl_param('kernel.sem').with(value: '250 100000 32 1024')
    end

    context 'creates scripts' do
      it 'creates scripts directory' do
        expect(chef_run).to create_directory('/var/opt/gitlab/patroni/scripts').with(owner: 'postgres', group: 'postgres')
      end

      it 'creates wale-restore scripts' do
        expect(chef_run).to create_cookbook_file('/var/opt/gitlab/patroni/scripts/wale-restore.sh').with(owner: 'postgres', group: 'postgres', mode: '0754')
      end
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

    it 'installs runit' do
      expect(chef_run).to install_package('runit')
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
      context 'patroni service is not running or is not in a running state' do
        before do
          stub_command(guard_command).and_return(false)
        end

        it 'does not update the config' do
          expect(chef_run).not_to run_execute('update bootstrap config')
        end
      end

      context 'patroni service is running' do
        it 'updates the config' do
          command = <<-CMD
/opt/patroni/bin/patronictl -c /var/opt/gitlab/patroni/patroni.yml edit-config --force --replace - <<-YML
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

      expect(chef_run).to render_file(config_path).with_content("if $programname == 'patroni' then /var/log/gitlab/patroni/patroni.log;svlogd_format")
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end

    it 'creates PostgreSQL rsyslog config' do
      config_path = '/etc/rsyslog.d/51-postgresql.conf'

      expect(chef_run).to render_file(config_path).with_content("if $programname == 'postgres' then /var/log/gitlab/postgresql/postgresql.log;svlogd_format")
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end

    it 'creates WAL-E rsyslog config' do
      config_path = '/etc/rsyslog.d/52-wale.conf'

      expect(chef_run).to render_file(config_path).with_content("if $programname contains 'wal_e' then /var/log/gitlab/postgresql/wale.log;svlogd_format")
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end

    it 'creates .pgpass' do
      pgpass_path    = '/var/opt/gitlab/postgresql/.pgpass'
      pgpass_content = 'localhost:5433:*:gitlab-superuser:superuser-password'

      expect(chef_run).to create_template(pgpass_path).with(owner: 'postgres', group: 'postgres', mode: '0600')
      expect(chef_run).to render_file(pgpass_path).with_content(pgpass_content)
    end

    it 'creates gitlab-psql' do
      gitlab_psql_path    = '/usr/local/bin/gitlab-psql'
      gitlab_psql_content = <<-STR
#!/bin/sh

if [ "$(id -n -u)" = "postgres" ] ; then
  privilege_drop=''
else
  privilege_drop="-u postgres"
fi

cd /tmp; exec chpst ${privilege_drop} -U postgres psql -p 5433 -h localhost -U gitlab-superuser -d gitlabhq_production "$@"
      STR

      expect(chef_run).to create_template(gitlab_psql_path).with(mode: '0777')
      expect(chef_run).to render_file(gitlab_psql_path).with_content(gitlab_psql_content)
    end

    it 'creates gitlab-patronictl' do
      gitlab_patronictl_path    = '/usr/local/bin/gitlab-patronictl'
      gitlab_patronictl_content = <<-STR
#!/bin/sh

cd /tmp; exec chpst -U postgres /opt/patroni/bin/patronictl -c /var/opt/gitlab/patroni/patroni.yml "$@"
      STR

      expect(chef_run).to create_template(gitlab_patronictl_path).with(mode: '0777')
      expect(chef_run).to render_file(gitlab_patronictl_path).with_content(gitlab_patronictl_content)
    end

    it 'rotates Patroni logs' do
      expect(chef_run).to enable_logrotate_app('patroni').with(
        path: '/var/log/gitlab/patroni/patroni.log',
        options: %w(missingok compress delaycompress notifempty),
        rotate: 7,
        frequency: 'daily'
      )
    end

    it 'rotates PostgreSQL logs' do
      expect(chef_run).to enable_logrotate_app('postgresql').with(
        path: '/var/log/gitlab/postgresql/postgresql.log',
        options: %w(missingok compress delaycompress notifempty),
        rotate: 7,
        frequency: 'daily'
      )
    end

    it 'rotates WAL-E logs' do
      expect(chef_run).to enable_logrotate_app('wale').with(
        path: '/var/log/gitlab/postgresql/wale.log',
        options: %w(missingok compress delaycompress notifempty),
        rotate: 7,
        frequency: 'daily'
      )
    end
  end
end
