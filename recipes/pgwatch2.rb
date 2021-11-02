# Cookbook:: gitlab-patroni
# Recipe:: pgwatch2
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install and configure pgwatch2 Ubuntu package (https://github.com/cybertec-postgresql/pgwatch2) and all the required
# dependencies according to Postgres.ai documentation
# (https://gitlab.com/postgres-ai/pgwatch2/-/blob/afe5428397afd991f6d86d63ab756b97f1d5c7e1/docs/postgres.ai_edition_yaml_setup.md).

# Skip this recipe if Ubuntu is older than 18.04
if node['platform_version'].to_i < 18
  log %q(This recipe doesn't support Ubuntu versions older than 18.04.)
  return
end

package 'git'

include_recipe '::pgwatch2_influxdb'

remote_file "#{Chef::Config[:file_cache_path]}/pgwatch2.deb" do
  source node['gitlab-patroni']['postgresql']['monitoring']['pgwatch2']['download_url']
end

dpkg_package 'pgwatch2' do
  source "#{Chef::Config[:file_cache_path]}/pgwatch2.deb"
end

template '/etc/pgwatch2/config/instances.yaml' do
  source 'postgresql/monitoring/pgwatch2/instances.yml.erb'
  variables({
    database_name: node['gitlab-patroni']['postgresql']['monitoring']['pgwatch2']['database_name'],
    database_host: node['gitlab-patroni']['postgresql']['monitoring']['pgwatch2']['database_host'],
    database_port: node['gitlab-patroni']['postgresql']['parameters']['port'],
    database_user: node['gitlab-patroni']['patroni']['users']['superuser']['username'],
    database_password: node['gitlab-patroni']['patroni']['users']['superuser']['password']
  })
  notifies :restart, 'service[pgwatch2]', :delayed
end

template '/etc/systemd/system/pgwatch2.service' do
  source 'postgresql/monitoring/pgwatch2/pgwatch2.service.erb'
  sensitive true
  variables({
    influxdb_password: node['gitlab-patroni']['patroni']['users']['superuser']['password']
  })
  notifies :restart, 'service[pgwatch2]', :delayed
end

git 'Checkout pgwatch2 Postgres.ai Edition metrics' do
  repository 'https://gitlab.com/postgres-ai/pgwatch2.git'
  checkout_branch 'Postgres.ai_v1.8.5'
  destination "#{Chef::Config[:file_cache_path]}/postgres_ai"
end

directory '/etc/pgwatch2/metrics' do
  recursive true
  action :delete
  only_if 'ls /etc/pgwatch2/metrics'
end

execute 'Copy Postgres.ai metrics to pgwatch2' do
  command "cp -r #{Chef::Config[:file_cache_path]}/postgres_ai/pgwatch2/metrics /etc/pgwatch2/"
  notifies :restart, 'service[pgwatch2]', :delayed
end

group 'pgwatch2'

user 'pgwatch2' do
  gid 'pgwatch2'
end

service 'pgwatch2' do
  action [:enable, :start]
  subscribes :restart, 'template[/etc/pgwatch2/config/instances.yaml]', :delayed
end
