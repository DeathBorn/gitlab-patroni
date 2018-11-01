# Cookbook Name:: gitlab-patroni
# Recipe:: postgresql
# License:: MIT
#
# Copyright 2018, GitLab Inc.

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(node)
postgresql_config_directory = node['gitlab-patroni']['postgresql']['config_directory']

directory postgresql_config_directory do
  recursive true
end

user postgresql_helper.postgresql_user do
  home postgresql_config_directory
  manage_home true
  not_if { node['etc']['passwd'].key?(postgresql_helper.postgresql_user) }
end

postgresql_server_install 'postgresql' do
  version node['gitlab-patroni']['postgresql']['version']
end

service 'postgresql' do
  action %i[stop disable]
end

file "#{postgresql_config_directory}/cacert.pem" do
  content node['gitlab-patroni']['postgresql']['ssl_ca']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_config_directory}/server.crt" do
  content node['gitlab-patroni']['postgresql']['ssl_cert']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_config_directory}/server.key" do
  content node['gitlab-patroni']['postgresql']['ssl_key']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end
