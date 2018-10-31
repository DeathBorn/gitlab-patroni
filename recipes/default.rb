# Cookbook Name:: gitlab-patroni
# Recipe:: default
# License:: MIT
#
# Copyright 2018, GitLab Inc.

data_directory              = node['gitlab-patroni']['data_directory']
install_directory           = node['gitlab-patroni']['install_directory']
log_directory               = node['gitlab-patroni']['log_directory']
postgresql_log_directory    = node['gitlab-patroni']['postgresql_log_directory']
postgresql_config_directory = node['gitlab-patroni']['config']['postgresql']['config_dir']
postgres_user               = node['gitlab-patroni']['user']
postgresql_group            = node['gitlab-patroni']['group']
postgres_listen_port        = node['gitlab-patroni']['config']['postgresql']['listen'].split(':').last
patroni_listen_port         = node['gitlab-patroni']['config']['restapi']['listen'].split(':').last
secrets_hash                = node['gitlab-patroni']['secrets']
patroni_config_path         = "#{data_directory}/patroni.yml"
secrets                     = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
address_detector            = AddressDetector.new(node, node['gitlab-patroni']['bind_interface'])

node.default['gitlab-patroni']['config']['restapi']['connect_address']    = "#{address_detector.ipaddress}:#{patroni_listen_port}"
node.default['gitlab-patroni']['config']['postgresql']['connect_address'] = "#{address_detector.ipaddress}:#{postgres_listen_port}"

Chef::Mixin::DeepMerge.deep_merge!(secrets['gitlab-patroni'], node.default['gitlab-patroni'])

apt_update

python_runtime node['gitlab-patroni']['python_runtime_version'] do
  pip_version node['gitlab-patroni']['pip_version']
end

python_virtualenv install_directory do
  pip_version node['gitlab-patroni']['pip_version']
end

python_package 'patroni[consul]' do
  version node['gitlab-patroni']['version']
end

directory File.dirname(data_directory) do
  recursive true
end

user postgres_user do
  home data_directory
  manage_home true
  not_if { node['etc']['passwd'].key?(postgres_user) }
end

directory postgresql_config_directory do
  recursive true
  owner postgres_user
  group postgresql_group
end

file "#{postgresql_config_directory}/postgresql.conf" do
  owner postgres_user
  group postgresql_group
end

file patroni_config_path do
  content YAML.dump(node['gitlab-patroni']['config'].to_hash)
  owner postgres_user
  group postgresql_group
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
  postgresql_log_directory
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
