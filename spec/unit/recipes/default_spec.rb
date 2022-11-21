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
      node.normal['gitlab-patroni']['patroni']['use_custom_scripts'] = true
      node.normal['gitlab-patroni']['patroni']['config']['postgresql']['wal_e']['command'] = '/var/opt/gitlab/patroni/scripts/wale-restore.sh'
      node.normal['gitlab-patroni']['patroni']['config']['postgresql']['wal_e']['restore_cmd'] = '/usr/bin/envdir /etc/wal-e.d/env /opt/wal-e/bin/wal-e backup-fetch'
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

    it 'installs postgresql-server-dev' do
      expect(chef_run).to install_package('postgresql-server-dev-12')
    end

    it 'adds PostgreSQL APT repository' do
      expect(chef_run).to add_apt_repository('postgresql').with(
        uri: 'https://download.postgresql.org/pub/repos/apt/',
        components: %w(main 12),
        distribution: 'xenial-pgdg',
        key: ['https://download.postgresql.org/pub/repos/apt/ACCC4CF8.asc'],
        cache_rebuild: true
      )
    end

    it 'adds GitLab Aptly repository' do
      expect(chef_run).to add_apt_repository('gitlab-aptly').with(
        uri: 'http://aptly.gitlab.com/gitlab-utils',
        components: %w(main),
        distribution: 'xenial',
        key: ['http://aptly.gitlab.com/release.asc'],
        cache_rebuild: true
      )
    end

    it 'installs postgresql' do
      expect(chef_run).to install_package('postgresql-12')
    end

    it 'installs postgresql-dbg' do
      expect(chef_run).to install_package('postgresql-12-dbg')
    end

    context 'with ubuntu xenial and dbg_debug_package set to false' do
      platform 'ubuntu', '16.04'
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['postgresql']['dbg_debug_package'] = false
        end.converge(described_recipe)
      end

      it 'does not install postgresql-dbg' do
        expect(chef_run).not_to install_package('postgresql-12-dbg')
      end
    end

    context 'with install_debug_package set to false' do
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['postgresql']['install_debug_package'] = false
        end.converge(described_recipe)
      end

      it 'does not install postgresql-dbg' do
        expect(chef_run).not_to install_package('postgresql-12-dbg')
      end
    end

    describe 'use_gitlab_aptly' do
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['postgresql']['use_gitlab_aptly'] = use_gitlab_aptly
        end.converge(described_recipe)
      end

      context 'when set to true' do
        let(:use_gitlab_aptly) { true }

        it 'creates an apt_preference with a high priority' do
          expect(chef_run).to add_apt_preference('postgresql').with(
            glob: 'postgresql-*',
            pin: 'origin aptly.gitlab.com',
            pin_priority: '1001'
          )
        end
      end

      context 'when set to false' do
        let(:use_gitlab_aptly) { false }

        it 'creates an apt_preference with a low priority' do
          expect(chef_run).to add_apt_preference('postgresql').with(
            glob: 'postgresql-*',
            pin: 'origin aptly.gitlab.com',
            pin_priority: '400'
          )
        end
      end
    end

    it 'installs pg_repack extension' do
      expect(chef_run).to install_package('postgresql-12-repack')
    end

    describe 'postgresql.base.conf' do
      let(:conf_path) { '/var/opt/gitlab/postgresql/postgresql.base.conf' }

      context 'when it already exists' do
        before do
          allow(File).to receive(:exist?).and_call_original
          allow(File).to receive(:exist?).with(conf_path).and_return(true)
        end

        it 'updates the file' do
          expect(chef_run).to create_cookbook_file(conf_path).with(owner: 'postgres', group: 'postgres')
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
          expect(chef_run).to create_user('postgres').with(home: '/var/opt/gitlab/postgresql')
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
      expect(chef_run).to apply_sysctl('kernel.shmmax').with(value: '123480309760')
    end

    it 'sets shmall kernel parameter' do
      expect(chef_run).to apply_sysctl('kernel.shmall').with(value: '30146560')
    end

    it 'sets sem kernel parameter' do
      expect(chef_run).to apply_sysctl('kernel.sem').with(value: '250 100000 32 1024')
    end

    context 'creates scripts' do
      it 'creates scripts directory' do
        expect(chef_run).to create_directory('/var/opt/gitlab/patroni/scripts').with(owner: 'postgres', group: 'postgres')
      end

      it 'creates wale-restore script' do
        expect(chef_run).to create_cookbook_file('/var/opt/gitlab/patroni/scripts/wale-restore.sh').with(owner: 'postgres', group: 'postgres', mode: '0754')
      end

      it 'creates post-failover-maintenance script' do
        expect(chef_run).to create_template('/var/opt/gitlab/patroni/scripts/post-failover-maintenance.sh').with(owner: 'postgres', group: 'postgres', mode: '0754')
      end
    end
  end

  describe 'Patroni' do
    it 'updates apt' do
      expect(chef_run).to periodic_apt_update('apt update')
    end

    it 'installs build_essential' do
      expect(chef_run).to install_package('build-essential')
    end

    it 'installs Python runtime' do
      expect(chef_run).to install_python_runtime('3').with(pip_version: '18.0')
    end

    it 'creates Patroni virtualenv' do
      expect(chef_run).to create_python_virtualenv('/opt/patroni').with(pip_version: '18.0')
    end

    it 'installs Psycopg2' do
      expect(chef_run).to install_python_package('psycopg2').with(version: '2.8.5')
    end

    it 'installs pg_activity' do
      expect(chef_run).to install_python_package('pg_activity').with(version: '1.6.2')
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

      expect(chef_run).to create_file(config_path).with(owner: 'postgres', group: 'postgres', mode: '0600', content: patroni_config)
      expect(chef_run.file(config_path)).to notify('poise_service[patroni]').to(:reload).delayed
    end

    context 'when tags are overridden' do
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['patroni']['config']['postgresql']['wal_e']['command'] = '/var/opt/gitlab/patroni/scripts/wale-restore.sh'
          node.normal['gitlab-patroni']['patroni']['config']['postgresql']['wal_e']['restore_cmd'] = '/usr/bin/envdir /etc/wal-e.d/env /opt/wal-e/bin/wal-e backup-fetch'
          node.normal['gitlab-patroni']['patroni']['config']['tags']['nofailover'] = true
          node.normal['gitlab-patroni']['patroni']['config']['tags']['noloadbalance'] = true
        end.converge(described_recipe)
      end

      it 'creates patroni.yml' do
        config_path    = '/var/opt/gitlab/patroni/patroni.yml'
        patroni_config = File.read('spec/fixtures/patroni-tags.yml')

        expect(chef_run).to create_file(config_path).with(owner: 'postgres', group: 'postgres', content: patroni_config)
        expect(chef_run.file(config_path)).to notify('poise_service[patroni]').to(:reload).delayed
      end
    end

    context 'when pg_ctl_timeout is set' do
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['patroni']['config']['postgresql']['wal_e']['command'] = '/var/opt/gitlab/patroni/scripts/wale-restore.sh'
          node.normal['gitlab-patroni']['patroni']['config']['postgresql']['wal_e']['restore_cmd'] = '/usr/bin/envdir /etc/wal-e.d/env /opt/wal-e/bin/wal-e backup-fetch'
          node.normal['gitlab-patroni']['patroni']['config']['postgresql']['pg_ctl_timeout'] = 1234
        end.converge(described_recipe)
      end

      it 'creates patroni.yml' do
        config_path    = '/var/opt/gitlab/patroni/patroni.yml'
        patroni_config = File.read('spec/fixtures/patroni-pg_ctl_timeout.yml')

        expect(chef_run).to create_file(config_path).with(owner: 'postgres', group: 'postgres', content: patroni_config)
        expect(chef_run.file(config_path)).to notify('poise_service[patroni]').to(:reload).delayed
      end
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

    describe 'disabling statement_timeout for superuser' do
      context 'patroni service is not running or is not in a running state' do
        before do
          stub_command(guard_command).and_return(false)
        end

        it 'does not run the query' do
          expect(chef_run).not_to run_execute('disable statement_timeout for superuser')
        end
      end

      context 'patroni service is running' do
        it 'run the query' do
          command = '/opt/patroni/bin/patronictl -c /var/opt/gitlab/patroni/patroni.yml query --role master --command \'ALTER USER "gitlab-superuser" SET statement_timeout=0\' --username gitlab-superuser --dbname postgres'

          expect(chef_run).to run_execute('disable statement_timeout for superuser').with(command: command, environment: { 'PGPASSWORD' => 'superuser-password' })
        end
      end
    end

    it 'creates Patroni log directory' do
      expect(chef_run).to create_directory('/var/log/gitlab/patroni').with(owner: 'syslog', group: 'syslog')
    end

    it 'creates Patroni rsyslog config' do
      config_path = '/etc/rsyslog.d/50-patroni.conf'

      expect(chef_run).to render_file(config_path).with_content("if $programname == 'patroni' then /var/log/gitlab/patroni/patroni.log;svlogd_format")
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end

    context 'when log_destination is syslog' do
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['postgresql']['parameters']['log_destination'] = 'syslog'
        end.converge(described_recipe)
      end

      it 'creates PostgreSQL rsyslog config' do
        config_path = '/etc/rsyslog.d/51-postgresql.conf'

        expect(chef_run).to render_file(config_path).with_content("if $programname == 'postgres' then /var/log/gitlab/postgresql/postgresql.log;svlogd_format")
        expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
      end

      it 'creates PostgreSQL log directory' do
        expect(chef_run).to create_directory('/var/log/gitlab/postgresql').with(owner: 'syslog', group: 'syslog')
      end

      it 'rotates PostgreSQL logs' do
        expect(chef_run).to enable_logrotate_app('postgresql').with(
          path: ['/var/log/gitlab/postgresql/postgresql.log', '/var/log/gitlab/postgresql/postgresql.csv'],
          options: %w(missingok compress delaycompress notifempty),
          rotate: 7,
          frequency: 'daily'
        )
      end
    end

    context 'when log_destination is not syslog' do
      let(:chef_run) do
        ChefSpec::ServerRunner.new do |node|
          node.normal['etc']['passwd'] = {}
          node.normal['gitlab-patroni']['postgresql']['parameters']['log_destination'] = 'stderr'
        end.converge(described_recipe)
      end

      it 'creates PostgreSQL log directory' do
        expect(chef_run).to create_directory('/var/log/gitlab/postgresql').with(owner: 'postgres', group: 'postgres')
      end

      it 'creates PostgreSQL log file' do
        expect(chef_run).to create_file('/var/log/gitlab/postgresql/postgresql.log').with(owner: 'postgres', group: 'postgres')
      end

      it 'doesnt create PostgreSQL rsyslog config' do
        config_path = '/etc/rsyslog.d/51-postgresql.conf'

        expect(chef_run).not_to render_file(config_path)
        expect(chef_run.file(config_path)).to notify('service[rsyslog]').to(:restart).delayed
      end

      it 'rotates PostgreSQL logs' do
        expect(chef_run).to enable_logrotate_app('postgresql').with(
          path: ['/var/log/gitlab/postgresql/postgresql.log', '/var/log/gitlab/postgresql/postgresql.csv'],
          options: %w(missingok compress delaycompress notifempty copytruncate),
          rotate: 7,
          frequency: 'daily'
        )
      end
    end

    it 'creates WAL-E rsyslog config' do
      config_path = '/etc/rsyslog.d/52-wale.conf'

      expect(chef_run).to render_file(config_path).with_content("if $programname contains 'wal_e' then /var/log/gitlab/postgresql/wale.log;svlogd_format")
      expect(chef_run.template(config_path)).to notify('service[rsyslog]').to(:restart).delayed
    end

    it 'creates .pgpass' do
      pgpass_path    = '/var/opt/gitlab/postgresql/.pgpass'
      pgpass_content = 'localhost:5432:*:gitlab-superuser:superuser-password'

      expect(chef_run).to create_template(pgpass_path).with(owner: 'postgres', group: 'postgres', mode: '0600')
      expect(chef_run).to render_file(pgpass_path).with_content(pgpass_content)
    end

    it 'creates gitlab-psql' do
      gitlab_psql_path    = '/usr/local/bin/gitlab-psql'
      gitlab_psql_content = <<-STR
#!/bin/sh

if [ "$(id -n -u)" = "postgres" ] ; then
  cd /tmp; /usr/bin/psql -p 5432 -h localhost -U gitlab-superuser -d gitlabhq_production "${@}"
else
  cd /tmp; sudo runuser -u postgres -- /usr/bin/psql -p 5432 -h localhost -U gitlab-superuser -d gitlabhq_production "${@}"
fi
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

    it 'creates gitlab-pg_activity' do
      gitlab_pg_activity_path = '/usr/local/bin/gitlab-pg_activity'
      mock_gitlab_pg_activity_path = 'spec/fixtures/gitlab-pg_activity.sh'
      mock_script_content = File.read(mock_gitlab_pg_activity_path)

      expect(chef_run).to create_cookbook_file(gitlab_pg_activity_path).with(mode: '0777')
      expect(chef_run).to render_file(gitlab_pg_activity_path).with_content(mock_script_content)
    end

    it 'rotates Patroni logs' do
      expect(chef_run).to enable_logrotate_app('patroni').with(
        path: '/var/log/gitlab/patroni/patroni.log',
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
