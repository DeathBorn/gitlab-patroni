# Cookbook Name:: gitlab-patroni
# Recipe:: consul
# License:: MIT
#
# Copyright 2018, GitLab Inc.
postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(node)
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