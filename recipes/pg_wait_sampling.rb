# Cookbook:: gitlab-patroni
# Recipe:: pg_wait_sampling
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install the pg_wait_sampling package from PostgreSQL Global Development Group (PGDG) repository.

postgresql_version = node['gitlab-patroni']['postgresql']['version']

apt_package "postgresql-#{postgresql_version}-pg-wait-sampling" do
  action :install
end
