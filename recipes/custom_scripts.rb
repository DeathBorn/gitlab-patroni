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

template "#{scripts_directory}/analyze-db.sh" do
  source "#{File.basename(name)}.erb"
  mode '0754'
  variables(
    statistics_targets: node['gitlab-patroni']['patroni']['post_failover']['analyze_db']['statistics_targets']
  )
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end
