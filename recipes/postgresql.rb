# Cookbook:: gitlab-patroni
# Recipe:: postgresql
# License:: MIT
#
# Copyright:: 2018, GitLab Inc.

# We can't have secrets merging inside `AttributesHelper` because `get_secrets` is not
# designed to work inside a module
secrets_hash = node['gitlab-patroni']['secrets']
secrets      = get_secrets(secrets_hash['backend'], secrets_hash['path'], secrets_hash['key'])
patroni_conf = node.to_hash
patroni_conf['gitlab-patroni'] = Chef::Mixin::DeepMerge.deep_merge(secrets['gitlab-patroni'], patroni_conf['gitlab-patroni'])
patroni_conf = GitlabPatroni::AttributesHelper.populate_missing_values(patroni_conf)

postgresql_helper           = GitlabPatroni::PostgresqlHelper.new(patroni_conf)
postgresql_config_directory = patroni_conf['gitlab-patroni']['postgresql']['config_directory']

# Needed to support Postgres 12 as deployed on May 8: we need to de-couple gitlab-psql's
# home directory from the postgres config_directory; with conditional assigment, we will
# support the old way in older environment, the new way in newer environments
postgresql_user_home = node['gitlab-patroni']['postgresql']['pg_user_homedir'].nil? ? postgresql_config_directory : node['gitlab-patroni']['postgresql']['pg_user_homedir']

directory postgresql_user_home do
  recursive true
end

user postgresql_helper.postgresql_user do
  home postgresql_user_home
  manage_home true
  not_if { patroni_conf['etc']['passwd'].key?(postgresql_helper.postgresql_user) }
end

directory postgresql_user_home do
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

directory postgresql_config_directory do
  recursive true
  mode '0700'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
end

apt_update 'apt update'

# Adapted from the postgresql cookbook
package 'apt-transport-https'

apt_repository 'postgresql' do
  uri          'https://download.postgresql.org/pub/repos/apt/'
  components   ['main', postgresql_helper.version]
  distribution "#{patroni_conf['lsb']['codename']}-pgdg"
  key 'https://download.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
  cache_rebuild true
end

package "postgresql-#{postgresql_helper.version}"

if node['lsb']['codename'] == 'xenial'
  package "postgresql-#{postgresql_helper.version}-dbg"
else
  package "postgresql-#{postgresql_helper.version}-dbgsym"
end

package "postgresql-#{postgresql_helper.version}-repack"
# Needed by psycopg2 >= 2.8 which is a dependency of Patroni
package "postgresql-server-dev-#{postgresql_helper.version}"

service 'postgresql' do
  action %i[stop disable]
end

cookbook_file "#{postgresql_config_directory}/postgresql.base.conf" do
  source 'postgresql.conf'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group

  # If this file already exists, manage it in Chef. If it doesn't, it means that:
  # a. We're adding a new node, in which case we want patroni to create the configuration
  # b. We're initializing a new cluster. Since this case is a rare occurrence, we leave
  # creating this file as a manual action (a simple `touch` is enough for chef to take
  # over).
  only_if { ::File.exist?(name) }
end

file "#{postgresql_user_home}/cacert.pem" do
  content patroni_conf['gitlab-patroni']['postgresql']['ssl_ca']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_user_home}/server.crt" do
  content patroni_conf['gitlab-patroni']['postgresql']['ssl_cert']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

file "#{postgresql_user_home}/server.key" do
  content patroni_conf['gitlab-patroni']['postgresql']['ssl_key']
  mode '0600'
  owner postgresql_helper.postgresql_user
  group postgresql_helper.postgresql_group
  sensitive true
end

sysctl 'kernel.shmmax' do
  value patroni_conf['gitlab-patroni']['postgresql']['shmmax']
end

sysctl 'kernel.shmall' do
  value patroni_conf['gitlab-patroni']['postgresql']['shmall']
end

sem = [
  patroni_conf['gitlab-patroni']['postgresql']['semmsl'],
  patroni_conf['gitlab-patroni']['postgresql']['semmns'],
  patroni_conf['gitlab-patroni']['postgresql']['semopm'],
  patroni_conf['gitlab-patroni']['postgresql']['semmni'],
].join(' ')
sysctl 'kernel.sem' do
  value sem
end
