# Cookbook:: gitlab-patroni
# Recipe:: custom_scripts
# License:: MIT
#
# Copyright:: 2019, GitLab Inc.

# We can't have secrets merging inside `AttributesHelper` because `get_secrets` is not
# designed to work inside a module
secrets_hash = node['gitlab-patroni']['secrets']
secrets      = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
patroni_conf = node.to_hash
patroni_conf['gitlab-patroni'] = Chef::Mixin::DeepMerge.deep_merge(secrets['gitlab-patroni'], patroni_conf['gitlab-patroni']).to_hash
patroni_conf = GitlabPatroni::AttributesHelper.populate_missing_values(patroni_conf)

postgresql_helper = GitlabPatroni::PostgresqlHelper.new(patroni_conf)
scripts_directory = "#{patroni_conf['gitlab-patroni']['patroni']['config_directory']}/scripts"

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
    superuser: patroni_conf['gitlab-patroni']['patroni']['users']['superuser']['username'],
    db_name: 'gitlabhq_production',
    jobs: 16
  )
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end
