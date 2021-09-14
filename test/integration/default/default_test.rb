# InSpec tests for recipe gitlab-patroni::default

control 'general-checks' do
  impact 1.0
  title 'General tests for gitlab-patroni cookbook'
  desc '
    This control ensures that:
      * there is no duplicates in /etc/group'

  describe etc_group do
    its('gids') { should_not contain_duplicates }
  end
end

control 'Patroni' do
  impact 1.0
  title 'Verify Patroni configuration'
  desc 'This control ensures that the patroni configuration is accurate'

  describe command('gitlab-patronictl') do
    it { should exist }
  end

  describe service('patroni') do
    it { should be_installed }
    it { should be_enabled }
    it { should_not be_running }
  end

  describe file('/var/opt/gitlab/patroni/patroni.yml') do
    its('owner') { should eq 'postgres' }
    its('group') { should eq 'postgres' }
    its('content') { should match(/scope: pg-ha-cluster/) }
    its('content') { should match(/name: patroni-ubuntu/) }
    its('content') { should match(/restapi:/) }
    its('content') { should match(/listen: 0.0.0.0:8009/) }
    its('content') { should match(/connect_address: 127.0.0.1:8009/) }
    its('content') { should match(/consul:/) }
    its('content') { should match(/host: 127.0.0.1:8500/) }
    its('content') { should match(/bootstrap:/) }
    its('content') { should match(/dcs:/) }
    its('content') { should match(/ttl: 30/) }
    its('content') { should match(/loop_wait: 10/) }
    its('content') { should match(/retry_timeout: 10/) }
    its('content') { should match(/ maximum_lag_on_failover: 1048576/) }
    its('content') { should match(/postgresql:/) }
    its('content') { should match(/use_pg_rewind: true/) }
    its('content') { should match(/use_slots: true/) }
    its('content') { should match(/wal_level: replica/) }
    its('content') { should match(/hot_standby: 'on'/) }
    its('content') { should match(/wal_keep_segments: 8/) }
    its('content') { should match(/max_wal_senders: 5/) }
    its('content') { should match(/max_replication_slots: 5/) }
    its('content') { should match(/checkpoint_timeout: 30/) }
    its('content') { should match(/initdb:/) }
    its('content') { should match(/- encoding: UTF8/) }
    its('content') { should match(/- locale: C.UTF-8/) }
    its('content') { should match(/pg_hba:/) }
    its('content') { should match(%r{- host postgres gitlab-superuser 192.168.0.0/11 md5}) }
    its('content') { should match(%r{- host all gitlab-superuser 192.168.0.0/11 md5}) }
    its('content') { should match(%r{- host all gitlab-superuser 192.168.0.0/11 md5}) }
    its('content') { should match(%r{- host all gitlab-superuser 127.0.0.1/32 md5}) }
    its('content') { should match(%r{- host replication gitlab-replicator 127.0.0.1/32 md5}) }
    its('content') { should match(%r{- host replication gitlab-replicator 192.168.0.0/11 md5}) }
    its('content') { should match(/users:/) }
    its('content') { should match(/gitlab-superuser:/) }
    its('content') { should match(/password: superuser-password/) }
    its('content') { should match(/options:/) }
    its('content') { should match(/- createrole/) }
    its('content') { should match(/- createdb/) }
    its('content') { should match(/gitlab-replicator:/) }
    its('content') { should match(/password: replication-password/) }
    its('content') { should match(/- replication/) }
    its('content') { should match(/tags: {}/) }
    its('content') { should match(%r{data_dir: "/var/opt/gitlab/postgresql/data"}) }
    its('content') { should match(%r{config_dir: "/var/opt/gitlab/postgresql"}) }
    its('content') { should match(%r{bin_dir: "/usr/lib/postgresql/12/bin"}) }
    its('content') { should match(/listen: 0.0.0.0:5432/) }
    its('content') { should match(/port: 5432/) }
    its('content') { should match(/ssl: 'off'/) }
    its('content') { should match(/ssl_ciphers: HIGH:MEDIUM:\+3DES:\!aNULL:\!SSLv3:\!TLSv1/) }
    its('content') { should match(/log_destination: syslog/) }
    its('content') { should match(/shared_buffers: 512MB/) }
    its('content') { should match(/authentication/) }
    its('content') { should match(/superuser:/) }
    its('content') { should match(/username: gitlab-superuser/) }
    its('content') { should match(/replication/) }
    its('content') { should match(/username: gitlab-replicator/) }
    its('content') { should match(/connect_address: 127.0.0.1:5432/) }
  end
end
