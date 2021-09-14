# Cookbook:: gitlab-patroni
# Recipe:: pg_stat_kcache
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Install the pg_stat_kcache package from PostgreSQL Global Development Group (PGDG) repository.

postgresql_version = node['gitlab-patroni']['postgresql']['version']

apt_package "postgresql-#{postgresql_version}-pg-stat-kcache" do
  action :install
end
