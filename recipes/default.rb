# Cookbook Name:: gitlab-patroni
# Recipe:: default
# License:: MIT
#
# Copyright 2018, GitLab Inc.

# We can't have secrets merging inside `AttributesHelper` because `get_secrets` is not
# designed to work inside a module
secrets_hash = node['gitlab-patroni']['secrets']
secrets      = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
Chef::Mixin::DeepMerge.deep_merge!(secrets['gitlab-patroni'], node.normal['gitlab-patroni'])

GitlabPatroni::AttributesHelper.populate_missing_values(node)

include_recipe '::postgresql'
include_recipe '::patroni'

if node['gitlab-patroni']['patroni']['custom_scripts']
	include_recipe '::custom_scripts'
end

