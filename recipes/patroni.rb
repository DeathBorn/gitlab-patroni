# Cookbook Name:: gitlab-patroni
# Recipe:: patroni
# License:: MIT
#
# Copyright 2018, GitLab Inc.

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(node)
config_directory            = node['gitlab-patroni']['patroni']['config_directory']
install_directory           = node['gitlab-patroni']['patroni']['install_directory']
log_directory               = node['gitlab-patroni']['patroni']['log_directory']
postgresql_log_directory    = node['gitlab-patroni']['postgresql']['log_directory']
postgresql_config_directory = node['gitlab-patroni']['patroni']['config']['postgresql']['config_dir']
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

[
  config_directory,
  postgresql_config_directory
].each do |dir|
  directory dir do
    recursive true
    owner postgresql_helper.postgresql_user
    group postgresql_helper.postgresql_group
  end
end

# Patroni crashes if it didn't find a postgresql.conf to rename it, so we provide an empty one!
file "#{postgresql_config_directory}/postgresql.conf" do
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

file patroni_config_path do
  content YAML.dump(node['gitlab-patroni']['patroni']['config'].to_hash)
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  notifies :reload, 'poise_service[patroni]', :immediately
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
  source '50-patroni.conf.erb'
  variables(log_directory: log_directory)
  notifies :restart, 'service[rsyslog]', :delayed
end

template '/etc/rsyslog.d/51-postgresql.conf' do
  source '51-postgresql.conf.erb'
  variables(log_directory: postgresql_log_directory)
  notifies :restart, 'service[rsyslog]', :delayed
end
