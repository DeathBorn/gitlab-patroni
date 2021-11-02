# Cookbook:: gitlab-patroni
# Recipe:: default
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

# We can't have secrets merging inside `AttributesHelper` because `get_secrets` is not
# designed to work inside a module
secrets_hash = node['gitlab-patroni']['secrets']
secrets      = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
Chef::Mixin::DeepMerge.deep_merge!(secrets['gitlab-patroni'], node.normal['gitlab-patroni'])

GitlabPatroni::AttributesHelper.populate_missing_values(node)

include_recipe '::postgresql'
include_recipe '::patroni'

# https://gitlab.com/gitlab-com/gl-infra/chef-repo/-/blob/97b96f0c15295d2f4709ee77c060a15516c4136e/roles/gprd-base-db-patroni.json#L234
postgresql_shared_preload_libraries = node['gitlab-patroni']['postgresql']['parameters']['shared_preload_libraries']
  if !postgresql_shared_preload_libraries.nil? && postgresql_shared_preload_libraries.include?('pg_wait_sampling')
  include_recipe '::pg_wait_sampling'
end

if !postgresql_shared_preload_libraries.nil? && postgresql_shared_preload_libraries.include?('pg_stat_kcache')
  include_recipe '::pg_stat_kcache'
end
