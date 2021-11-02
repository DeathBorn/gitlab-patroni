# Cookbook:: gitlab-patroni
# Recipe:: pgwatch2_infl
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install and configure InfluxDB according to Postgres.ai documentation
# (https://gitlab.com/postgres-ai/pgwatch2/-/blob/afe5428397afd991f6d86d63ab756b97f1d5c7e1/docs/postgres.ai_edition_yaml_setup.md).

# Skip this recipe if Ubuntu is older than 18.04
if node['platform_version'].to_i < 18
  log %q(This recipe doesn't support Ubuntu versions older than 18.04.)
  return
end

remote_file "#{Chef::Config[:file_cache_path]}/influxdb.deb" do
  source   node['gitlab-patroni']['postgresql']['monitoring']['influxdb']['download_url']
end

dpkg_package 'influxdb' do
  source "#{Chef::Config[:file_cache_path]}/influxdb.deb"
end

service 'influxdb' do
  action [:enable, :start]
end

execute 'Create InfluxDB database for pgwatch2' do
  command 'influx -execute "CREATE DATABASE pgwatch2 WITH DURATION 30d REPLICATION 1 SHARD DURATION 1d NAME pgwatch2_def_ret"'
end

execute 'Create InfluxDB database user for pgwatch2' do
  command %Q(influx -execute "CREATE USER pgwatch2 WITH PASSWORD '#{node['gitlab-patroni']['patroni']['users']['superuser']['password']}'")
end

bash 'Grant permissions to InfluxDB database user for pgwatch2' do
    code <<-EOH
      influx -execute "GRANT READ ON pgwatch2 TO pgwatch2"
      influx -execute "GRANT WRITE ON pgwatch2 TO pgwatch2"
    EOH
end
