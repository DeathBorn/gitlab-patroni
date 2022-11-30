# Cookbook:: gitlab-patroni
# Recipe:: pg_wait_sampling
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install the pg_wait_sampling package from PostgreSQL Global Development Group (PGDG) repository.

postgresql_version = node['gitlab-patroni']['postgresql']['version']
pg_wait_sampling_reset_path = node['gitlab-patroni']['pg_wait_sampling']['pg_wait_sampling_reset_path']
log_path_prefix = node['gitlab-patroni']['pg_wait_sampling']['log_path_prefix']

apt_package "postgresql-#{postgresql_version}-pg-wait-sampling" do
  action :install
end

template pg_wait_sampling_reset_path do
  source 'pg_wait_sampling_reset.sh.erb'
  variables(
    log_path_prefix: log_path_prefix
  )
  mode '0755'
end

cron 'pg_wait_sampling reset' do
  minute node['gitlab-patroni']['pg_wait_sampling']['reset_cron']['minute']
  hour node['gitlab-patroni']['pg_wait_sampling']['reset_cron']['hour']
  weekday node['gitlab-patroni']['pg_wait_sampling']['reset_cron']['weekday']
  user node['gitlab-patroni']['pg_wait_sampling']['reset_cron']['user']
  command pg_wait_sampling_reset_path
  path '/usr/local/sbin:/usr/sbin/:/sbin:/usr/local/bin:/usr/bin:/bin:/snap/bin'
  action :create
end
