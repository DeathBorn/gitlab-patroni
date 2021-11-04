# Cookbook:: gitlab-patroni
# Recipe:: kitchen_enable_patroni
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
#  _________________________________
# /                                 \
# |     This recipe is intended     |
# |     for use with Test Kitchen.  |
# |     DO NOT use in Production.   |
# \_________________________________/
#                 !  !
#                 !  !
#                 L_ !
#                / _)!
#               / /__L
#         _____/ (____)
#                (____)
#         _____  (____)
#              \_(____)
#                 !  !
#                 !  !
#                 \__/

# Consul service expects a cluster instead of a single node. For test purposes, it was easier to run Consul in
# development mode.
service 'consul' do
  action [:disable, :stop]
end

execute 'Consul development mode' do
  command 'nohup consul agent -dev >> /var/log/consul_agent_dev.log &'
end

# Current Chef Cookbook logic assumes `postgresql.conf` already exists prior the execution. This is a workaround to
# enable Patroni execution.
file "#{node['gitlab-patroni']['postgresql']['config_directory']}/postgresql.conf" do
  action :touch
end

service 'patroni' do
  action [:start]
end

# Create database
default_role = node['gitlab-patroni']['user']
db_name = node['gitlab-patroni']['postgresql']['monitoring']['pgwatch2']['database_name']
execute "Create database #{db_name}" do
  command %(echo "SELECT 'CREATE DATABASE #{db_name}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '#{db_name}')\\gexec" | gitlab-psql -d #{default_role})
  retries 5
  retry_delay 5
end
