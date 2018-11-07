# Cookbook Name:: gitlab-patroni
# Recipe:: patroni
# License:: MIT
#
# Copyright 2018, GitLab Inc.

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(node)
config_directory            = node['gitlab-patroni']['patroni']['config_directory']
install_directory           = node['gitlab-patroni']['patroni']['install_directory']
log_directory               = node['gitlab-patroni']['patroni']['log_directory']
log_path                    = "#{log_directory}/patroni.log"
postgresql_log_directory    = node['gitlab-patroni']['postgresql']['log_directory']
postgresql_log_path         = "#{postgresql_log_directory}/postgres.log"
postgresql_superuser        = node['gitlab-patroni']['patroni']['users']['superuser']['username']
patroni_config_path         = "#{config_directory}/patroni.yml"

apt_update 'apt update'

python_runtime node['gitlab-patroni']['patroni']['python_runtime_version'] do
  pip_version node['gitlab-patroni']['patroni']['pip_version']
end

python_virtualenv install_directory do
  pip_version node['gitlab-patroni']['patroni']['pip_version']
end

python_package 'patroni[consul]' do
  version node['gitlab-patroni']['patroni']['version']
end

package 'runit'

directory config_directory do
  recursive true
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

file patroni_config_path do
  content YAML.dump(node['gitlab-patroni']['patroni']['config'].to_hash)
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  notifies :reload, 'poise_service[patroni]', :delayed
end

execute 'update bootstrap config' do
  command <<-CMD
#{install_directory}/bin/patronictl -c #{patroni_config_path} edit-config --force --replace - <<-YML
#{YAML.dump(node['gitlab-patroni']['patroni']['config']['bootstrap']['dcs'].to_hash)}
YML
  CMD
  only_if 'systemctl status patroni'
end

poise_service 'patroni' do
  command ''
  provider :systemd
  options :systemd, template: 'patroni.systemd.erb', never_start: true
end

service 'rsyslog' do
  supports [:restart]
end

[
  log_directory,
  postgresql_log_directory,
].each do |dir|
  directory dir do
    recursive true
    owner 'syslog'
    group 'syslog'
  end
end

template '/etc/rsyslog.d/50-patroni.conf' do
  source 'rsyslog.conf.erb'
  variables(
    program_name: 'patroni',
    log_path: log_path
  )
  notifies :restart, 'service[rsyslog]', :delayed
end

template '/etc/rsyslog.d/51-postgresql.conf' do
  source 'rsyslog.conf.erb'
  variables(
    program_name: 'postgres',
    log_path: postgresql_log_path
  )
  notifies :restart, 'service[rsyslog]', :delayed
end

template "#{node['gitlab-patroni']['postgresql']['config_directory']}/.pgpass" do
  source 'pgpass.erb'
  variables(
    hostname: 'localhost',
    port: postgresql_helper.postgresql_port,
    database: '*',
    username: postgresql_superuser,
    password: node['gitlab-patroni']['patroni']['users']['superuser']['password']
  )
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  mode '0600'
end

template '/usr/local/bin/gitlab-psql' do
  source 'gitlab-psql.erb'
  variables(
    postgresql_user: postgresql_helper.postgresql_user,
    port: postgresql_helper.postgresql_port,
    host: 'localhost',
    superuser: postgresql_superuser,
    db_name: 'gitlabhq_production'
  )
  mode '0777'
end

template '/usr/local/bin/gitlab-patronictl' do
  source 'gitlab-patronictl.erb'
  variables(
    postgresql_user: postgresql_helper.postgresql_user,
    install_directory: install_directory,
    config_path: patroni_config_path
  )
  mode '0777'
end

include_recipe 'logrotate::default'

{
  patroni: log_path,
  postgresql: postgresql_log_path
}.each do |app, app_path|
  logrotate_app app do
    path app_path
    options %w(missingok compress delaycompress notifempty)
    rotate 7
    frequency 'daily'
  end
end
