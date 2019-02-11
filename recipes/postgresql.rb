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

directory postgresql_config_directory do
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

# Adapted from the postgresql cookbook
package 'apt-transport-https'

apt_repository 'postgresql' do
  uri          'https://download.postgresql.org/pub/repos/apt/'
  components   ['main', postgresql_helper.version]
  distribution "#{node['lsb']['codename']}-pgdg"
  key 'https://download.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
  cache_rebuild true
end

package "postgresql-#{postgresql_helper.version}"
package "postgresql-#{postgresql_helper.version}-repack"

service 'postgresql' do
  action %i[stop disable]
end

cookbook_file "#{postgresql_config_directory}/postgresql.conf" do
  source File.basename(name)
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  # Patroni expects postgresql.conf to exist to move it to postgresql.base.conf,
  # managing postgresql.conf by itself, so we don't want to override it.
  action :create_if_missing
end

cookbook_file "#{postgresql_config_directory}/postgresql.base.conf" do
  source 'postgresql.conf'
  only_if { File.exist?(name) }
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

sysctl_param 'kernel.shmmax' do
  value node['gitlab-patroni']['postgresql']['shmmax']
end

sysctl_param 'kernel.shmall' do
  value node['gitlab-patroni']['postgresql']['shmall']
end

sem = [
  node['gitlab-patroni']['postgresql']['semmsl'],
  node['gitlab-patroni']['postgresql']['semmns'],
  node['gitlab-patroni']['postgresql']['semopm'],
  node['gitlab-patroni']['postgresql']['semmni'],
].join(' ')
sysctl_param 'kernel.sem' do
  value sem
end
