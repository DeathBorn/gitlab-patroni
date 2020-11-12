# Cookbook:: gitlab-patroni
# Recipe:: custom_scripts
# License:: MIT
#
# Copyright:: 2019, GitLab Inc.

postgresql_helper = GitlabPatroni::PostgresqlHelper.new(node)
scripts_directory = "#{node['gitlab-patroni']['patroni']['config_directory']}/scripts"

directory scripts_directory do
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

cookbook_file "#{scripts_directory}/wale-restore.sh" do
  source File.basename(name)
  mode '0754'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

template "#{scripts_directory}/post-failover-maintenance.sh" do
  source "#{File.basename(name)}.erb"
  mode '0754'
  variables(
    port: postgresql_helper.postgresql_port,
    host: 'localhost',
    superuser: node['gitlab-patroni']['patroni']['users']['superuser']['username'],
    db_name: 'gitlabhq_production',
    jobs: 16
  )
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end
