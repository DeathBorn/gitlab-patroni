# Cookbook:: gitlab-patroni
# Recipe:: query_snapshotting
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.

postgresql_helper        = GitlabPatroni::PostgresqlHelper.new(node)
snapshotting_script_path = node['gitlab-patroni']['query_snapshotting']['script_path']
pgpass_path              = "#{postgresql_helper.postgresql_user_home}/.query-snapshotting-pgass"

template snapshotting_script_path do
  source 'query-snapshotting.sh.erb'
  variables(
    scrape_interval: node['gitlab-patroni']['query_snapshotting']['scrape_interval'],
    pgpass_path: pgpass_path,
    node_name: node['hostname'],
    hostname: node['gitlab-patroni']['query_snapshotting']['destination']['host'],
    username: node['gitlab-patroni']['query_snapshotting']['destination']['user'],
    database: node['gitlab-patroni']['query_snapshotting']['destination']['database']
  )
  mode '0777'
end

template pgpass_path do
  source 'query-snapshotting-pgpass.erb'
  variables(
    password: node['gitlab-patroni']['query_snapshotting']['destination']['password']
  )
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
  mode '0600'
end

template '/etc/systemd/system/query-snapshotting.service' do
  source 'query-snapshotting.systemd.erb'
  variables()
  mode '0644'
  notifies :run, 'execute[reload systemd]', :immediately
  notifies :restart, 'service[query-snapshotting]', :delayed
end

execute 'reload systemd' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'query-snapshotting' do
  action %i(enable start)
end
