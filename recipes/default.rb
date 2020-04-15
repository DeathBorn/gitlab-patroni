# Cookbook:: gitlab-patroni
# Recipe:: default
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

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
